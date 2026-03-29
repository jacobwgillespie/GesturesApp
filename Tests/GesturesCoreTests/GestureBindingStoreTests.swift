import AppKit
import GesturesCore
import XCTest

final class GestureBindingStoreTests: XCTestCase {
    func testSaveAndLoadBindings() throws {
        let suiteName = "GestureBindingStoreTests.saveAndLoad.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let initialStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        let shortcut = ShortcutBinding(keyCode: 123, modifierFlags: [.control, .option])
        initialStore.updateShortcut(shortcut, for: .threeFingerTap)

        let reloadedStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        XCTAssertEqual(reloadedStore.binding(for: .threeFingerTap).action, .keyboardShortcut(shortcut))
    }

    func testDisabledGesturePersists() throws {
        let suiteName = "GestureBindingStoreTests.disabled.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let initialStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        initialStore.setEnabled(false, for: .threeFingerSwipeDown)

        let reloadedStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        XCTAssertFalse(reloadedStore.binding(for: .threeFingerSwipeDown).isEnabled)
    }

    func testHapticsTogglePersists() throws {
        let suiteName = "GestureBindingStoreTests.haptics.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let initialStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        initialStore.setHapticsEnabled(true, for: .twoFingerTipTapLeft)

        let reloadedStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        XCTAssertTrue(reloadedStore.binding(for: .twoFingerTipTapLeft).isHapticsEnabled)
    }

    func testResetRestoresDefaults() throws {
        let suiteName = "GestureBindingStoreTests.reset.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let store = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        store.updateShortcut(ShortcutBinding(keyCode: 124, modifierFlags: [.shift]), for: .twoFingerTipTapRight)
        store.resetToDefaults()

        XCTAssertEqual(
            store.binding(for: .twoFingerTipTapRight),
            GestureKind.twoFingerTipTapRight.defaultConfiguration
        )
    }

    func testActionKindPersists() throws {
        let suiteName = "GestureBindingStoreTests.actionKind.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let initialStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        initialStore.updateActionKind(.middleClick, for: .threeFingerSwipeDown)

        let reloadedStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        XCTAssertEqual(reloadedStore.binding(for: .threeFingerSwipeDown).action, .middleClick)
    }

    func testLegacyShortcutOnlyConfigurationMigrates() throws {
        struct LegacyConfiguration: Codable {
            var isEnabled: Bool
            var shortcut: ShortcutBinding
        }

        let suiteName = "GestureBindingStoreTests.legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let legacyShortcut = ShortcutBinding(keyCode: 124, modifierFlags: [.command])
        let encoder = JSONEncoder()
        let legacyData = try encoder.encode([
            GestureKind.threeFingerTap: LegacyConfiguration(isEnabled: true, shortcut: legacyShortcut),
        ])
        defaults.set(legacyData, forKey: "bindings")

        let migratedStore = GestureBindingStore(userDefaults: defaults, storageKey: "bindings")
        XCTAssertEqual(migratedStore.binding(for: .threeFingerTap).action, .keyboardShortcut(legacyShortcut))
        XCTAssertFalse(migratedStore.binding(for: .threeFingerTap).isHapticsEnabled)
    }
}
