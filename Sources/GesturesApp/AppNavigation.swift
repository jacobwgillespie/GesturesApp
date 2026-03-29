import AppKit
import SwiftUI

enum AppWindowID {
    static let troubleshooting = "troubleshooting"
}

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
    static func openTroubleshooting(using openWindow: OpenWindowAction) {
        activate()
        openWindow(id: AppWindowID.troubleshooting)
    }

    @MainActor
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
