import AppKit
import Carbon.HIToolbox

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case shiftCmdV, optCmdV, ctrlCmdV, ctrlOptV

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shiftCmdV: return "⇧⌘V"
        case .optCmdV: return "⌥⌘V"
        case .ctrlCmdV: return "⌃⌘V"
        case .ctrlOptV: return "⌃⌥V"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_ANSI_V) }

    var carbonModifiers: UInt32 {
        switch self {
        case .shiftCmdV: return UInt32(shiftKey | cmdKey)
        case .optCmdV: return UInt32(optionKey | cmdKey)
        case .ctrlCmdV: return UInt32(controlKey | cmdKey)
        case .ctrlOptV: return UInt32(controlKey | optionKey)
        }
    }
}

/// Pintasan keyboard global berbasis Carbon (tidak butuh izin Aksesibilitas).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(_ preset: HotKeyPreset) {
        installHandlerIfNeeded()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let id = EventHotKeyID(signature: OSType(0x434C_4250), id: 1) // "CLBP"
        let status = RegisterEventHotKey(preset.keyCode, preset.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("ClipBar: gagal mendaftarkan pintasan \(preset.label) (\(status))")
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { center.onPress?() }
            return noErr
        }, 1, &spec, userData, &handlerRef)
    }
}
