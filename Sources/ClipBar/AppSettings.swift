import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let autoPaste = "cb2.autoPaste"
        static let maxItems = "cb2.maxItems"
        static let paused = "cb2.paused"
        static let hotKey = "cb2.hotKey"
        static let welcomed = "cb2.welcomed"
    }

    private let defaults = UserDefaults.standard

    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Key.autoPaste) } }
    @Published var maxItems: Int { didSet { defaults.set(maxItems, forKey: Key.maxItems) } }
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: Key.paused) } }
    @Published var hotKey: HotKeyPreset { didSet { defaults.set(hotKey.rawValue, forKey: Key.hotKey) } }

    var welcomed: Bool {
        get { defaults.bool(forKey: Key.welcomed) }
        set { defaults.set(newValue, forKey: Key.welcomed) }
    }

    private init() {
        defaults.register(defaults: [
            Key.autoPaste: true,
            Key.maxItems: 200,
            Key.paused: false,
            Key.hotKey: HotKeyPreset.shiftCmdV.rawValue,
        ])
        autoPaste = defaults.bool(forKey: Key.autoPaste)
        maxItems = defaults.integer(forKey: Key.maxItems)
        paused = defaults.bool(forKey: Key.paused)
        hotKey = HotKeyPreset(rawValue: defaults.string(forKey: Key.hotKey) ?? "") ?? .shiftCmdV
    }
}
