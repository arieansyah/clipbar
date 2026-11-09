import AppKit
import SwiftUI

/// Panel tanpa border yang bisa menerima keyboard tanpa mengaktifkan aplikasi.
final class ClipPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 800, height: 520)

    let panel: ClipPanel
    let model = PanelModel()
    private let store: ClipStore
    private let watcher: ClipboardWatcher
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var lastHide = Date.distantPast

    init(store: ClipStore, watcher: ClipboardWatcher) {
        self.store = store
        self.watcher = watcher
        panel = ClipPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let actions = PanelActions(
            paste: { [weak self] in self?.use($0, paste: AppSettings.shared.autoPaste) },
            copyOnly: { [weak self] in self?.use($0, paste: false) },
            togglePin: { [weak self] in self?.store.togglePin($0.id) },
            delete: { [weak self] in self?.delete($0) },
            openSettings: { [weak self] in self?.openSettings() }
        )
        let host = NSHostingView(rootView: PanelView(store: store, model: model,
                                                     settings: AppSettings.shared, actions: actions))
        host.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = host
    }

    // MARK: - Tampil / sembunyi

    func toggle(anchor: NSStatusBarButton? = nil) {
        if panel.isVisible { hide(); return }
        // Klik ikon menu bar saat panel terbuka akan menutupnya lewat resignKey dulu.
        if Date().timeIntervalSince(lastHide) < 0.3 { return }
        show(anchor: anchor)
    }

    func show(anchor: NSStatusBarButton? = nil) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }

        model.query = ""
        model.filter = .all
        model.selectedID = nil

        position(anchor: anchor)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
        DispatchQueue.main.async { self.model.focusToken &+= 1 }
    }

    func hide() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        lastHide = Date()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    private func position(anchor: NSStatusBarButton?) {
        let size = Self.size
        if let button = anchor, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? rect
            let x = min(max(rect.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: rect.minY - size.height - 6))
            return
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { panel.center(); return }
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                     y: visible.minY + visible.height * 0.58 - size.height / 2))
    }

    // MARK: - Aksi

    private var results: [ClipItem] { model.results(from: store) }

    private func use(_ item: ClipItem, paste: Bool) {
        watcher.write(item)
        store.touch(item.id)
        let target = previousApp
        hide()
        guard paste else { return }
        guard Paster.isTrusted else {
            Paster.requestAccess()
            return
        }
        if let target {
            if #available(macOS 14.0, *) {
                target.activate()
            } else {
                target.activate(options: .activateIgnoringOtherApps)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { Paster.sendPaste() }
    }

    private func delete(_ item: ClipItem) {
        let list = results
        if let index = list.firstIndex(of: item) {
            let next = list.indices.contains(index + 1) ? list[index + 1] : (index > 0 ? list[index - 1] : nil)
            model.selectedID = next?.id
        }
        store.delete(item.id)
    }

    private func move(_ delta: Int) {
        let list = results
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == model.selectedID } ?? 0
        model.selectedID = list[min(max(current + delta, 0), list.count - 1)].id
    }

    private func cycleFilter(_ delta: Int) {
        let all = ClipFilter.allCases
        let index = all.firstIndex(of: model.filter) ?? 0
        model.filter = all[(index + delta + all.count) % all.count]
        model.selectedID = nil
    }

    private func openSettings() {
        hide()
        SettingsWindow.show()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === panel else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)
        let selected = model.selection(in: results)

        switch event.keyCode {
        case 53: // esc
            if model.query.isEmpty { hide() } else { model.query = "" }
            return nil
        case 125: move(1); return nil   // ↓
        case 126: move(-1); return nil  // ↑
        case 36, 76: // return
            if let selected { use(selected, paste: cmd ? false : AppSettings.shared.autoPaste) }
            return nil
        case 48: // tab
            cycleFilter(shift ? -1 : 1)
            return nil
        case 51 where cmd: // ⌘⌫
            if let selected { delete(selected) }
            return nil
        default:
            break
        }

        guard cmd, let chars = event.charactersIgnoringModifiers?.lowercased() else { return event }
        switch chars {
        case "p":
            if let selected { store.togglePin(selected.id) }
            return nil
        case ",":
            openSettings()
            return nil
        case "w":
            hide()
            return nil
        default:
            if let n = Int(chars), (1...9).contains(n) {
                let list = results
                if list.indices.contains(n - 1) { use(list[n - 1], paste: AppSettings.shared.autoPaste) }
                return nil
            }
            return event
        }
    }
}
