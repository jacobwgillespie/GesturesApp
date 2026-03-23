import AppKit

enum AppWindowID {
    static let troubleshooting = "troubleshooting"
}

enum AppNavigation {
    @MainActor
    static func activate() {
        NSApp.activate()
    }
}
