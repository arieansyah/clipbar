import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipStore.shared
    private let settings = AppSettings.shared
    private var statusItem: NSStatusItem!
    private var watcher: ClipboardWatcher!
    private var panel: PanelController!
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        watcher = ClipboardWatcher(store: store)
        watcher.start()
        panel = PanelController(store: store, watcher: watcher)
        setupStatusItem()

        HotKeyCenter.shared.onPress = { [weak self] in self?.panel.toggle() }
        HotKeyCenter.shared.register(settings.hotKey)

        settings.$hotKey.dropFirst().sink { HotKeyCenter.shared.register($0) }.store(in: &bag)
        settings.$maxItems.dropFirst().sink { [weak self] in self?.store.trim(max: $0) }.store(in: &bag)
        settings.$paused.sink { [weak self] in self?.statusItem.button?.appearsDisabled = $0 }.store(in: &bag)

        if !settings.welcomed {
            settings.welcomed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.panel.show() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    /// clipbar://open · clipbar://settings · clipbar://pause · clipbar://resume
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "clipbar" {
            switch url.host {
            case "settings": SettingsWindow.show()
            case "pause": settings.paused = true
            case "resume": settings.paused = false
            default: panel.show()
            }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipBar")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ClipBar"
        button.target = self
        button.action = #selector(statusClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            panel.toggle(anchor: statusItem.button)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(item("Buka ClipBar   \(settings.hotKey.label)", #selector(openPanel)))
        menu.addItem(.separator())
        menu.addItem(item(settings.paused ? "Lanjutkan Pemantauan" : "Jeda Pemantauan", #selector(togglePause)))
        menu.addItem(item("Hapus Riwayat…", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Pengaturan…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Keluar ClipBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openPanel() { panel.show() }

    @objc private func togglePause() { settings.paused.toggle() }

    @objc private func openSettings() { SettingsWindow.show() }

    @objc private func clearHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hapus riwayat clipboard?"
        alert.informativeText = "Item yang disematkan tetap disimpan."
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batal")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear(keepPinned: true)
        }
    }

    // MARK: - Main menu (agar ⌘C/⌘V/⌘A berfungsi di kolom pencarian)

    private func setupMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("Pengaturan…", #selector(openSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Keluar ClipBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        edit.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}
