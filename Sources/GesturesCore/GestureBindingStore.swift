import Combine
import Foundation

public final class GestureBindingStore: ObservableObject {
    public static let defaultsKey = "gestureBindings"

    @Published public private(set) var bindings: [GestureKind: GestureBindingConfiguration]

    private let userDefaults: UserDefaults
    private let storageKey: String
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard, storageKey: String = GestureBindingStore.defaultsKey) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? Self.decoder.decode([GestureKind: GestureBindingConfiguration].self, from: data) {
            bindings = GestureBindingStore.mergingMissingDefaults(into: decoded)
        } else {
            bindings = GestureBindingStore.defaultBindings
        }
    }

    public func binding(for gesture: GestureKind) -> GestureBindingConfiguration {
        bindings[gesture] ?? gesture.defaultConfiguration
    }

    public func updateConfiguration(_ configuration: GestureBindingConfiguration, for gesture: GestureKind) {
        bindings[gesture] = configuration
        persist()
    }

    public func updateShortcut(_ shortcut: ShortcutBinding, for gesture: GestureKind) {
        var configuration = binding(for: gesture)
        configuration.action = .keyboardShortcut(shortcut)
        updateConfiguration(configuration, for: gesture)
    }

    public func updateActionKind(_ actionKind: GestureActionKind, for gesture: GestureKind) {
        var configuration = binding(for: gesture)
        switch actionKind {
        case .keyboardShortcut:
            configuration.action = .keyboardShortcut(configuration.action.shortcut ?? gesture.defaultShortcutBinding)
        case .middleClick:
            configuration.action = .middleClick
        }
        updateConfiguration(configuration, for: gesture)
    }

    public func setEnabled(_ isEnabled: Bool, for gesture: GestureKind) {
        var configuration = binding(for: gesture)
        configuration.isEnabled = isEnabled
        updateConfiguration(configuration, for: gesture)
    }

    public func setHapticsEnabled(_ isEnabled: Bool, for gesture: GestureKind) {
        var configuration = binding(for: gesture)
        configuration.isHapticsEnabled = isEnabled
        updateConfiguration(configuration, for: gesture)
    }

    public func resetToDefaults() {
        bindings = Self.defaultBindings
        persist()
    }

    private func persist() {
        guard let data = try? Self.encoder.encode(bindings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func mergingMissingDefaults(into current: [GestureKind: GestureBindingConfiguration]) -> [GestureKind: GestureBindingConfiguration] {
        var merged = current
        for gesture in GestureKind.allCases where merged[gesture] == nil {
            merged[gesture] = gesture.defaultConfiguration
        }
        return merged
    }

    private static let defaultBindings: [GestureKind: GestureBindingConfiguration] = Dictionary(
        uniqueKeysWithValues: GestureKind.allCases.map { ($0, $0.defaultConfiguration) }
    )
}
