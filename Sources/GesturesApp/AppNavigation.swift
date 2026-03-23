import AppKit

enum AppWindowID {
    static let troubleshooting = "troubleshooting"
}

enum AppNavigation {
    @MainActor
    static func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func openSettings() {
        activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
