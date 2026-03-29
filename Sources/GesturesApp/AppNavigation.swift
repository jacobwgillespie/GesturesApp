import AppKit
import SwiftUI

enum AppNavigation {
    @MainActor
    static func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func openSettings(using openSettings: OpenSettingsAction) {
        activate()
        openSettings()
    }

    @MainActor
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
