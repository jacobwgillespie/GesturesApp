import AppKit
import SwiftUI

enum AppNavigation {
    private static let showSettingsWindowSelector = Selector(("showSettingsWindow:"))
    private static let showPreferencesWindowSelector = Selector(("showPreferencesWindow:"))

    @MainActor
    static func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func openSettings() {
        activate()

        if SettingsSceneBridge.shared.open() {
            return
        }

        if NSApp.sendAction(showSettingsWindowSelector, to: nil, from: nil) {
            return
        }

        _ = NSApp.sendAction(showPreferencesWindowSelector, to: nil, from: nil)
    }

    @MainActor
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
