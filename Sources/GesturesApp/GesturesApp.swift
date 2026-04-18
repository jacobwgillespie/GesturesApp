import AppKit
import SwiftUI

final class GesturesAppDelegate: NSObject, NSApplicationDelegate {
    private var hasHandledFirstActivation = false

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppNavigation.openSettings()
        }

        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard hasHandledFirstActivation else {
            hasHandledFirstActivation = true
            return
        }

        Task { @MainActor in
            AppNavigation.openSettings()
        }
    }
}

@main
struct GesturesApp: App {
    @NSApplicationDelegateAdaptor(GesturesAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            AppModel.shared.bootstrap()
        }
    }

    var body: some Scene {
        MenuBarExtra("Gestures", systemImage: "hand.tap.fill") {
            MenuBarContentView(model: model)
        }
        .commands {
            GesturesCommands(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
