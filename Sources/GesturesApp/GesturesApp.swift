import AppKit
import SwiftUI

final class GesturesAppDelegate: NSObject, NSApplicationDelegate {
    private var hasHandledFirstActivation = false
    private var statusItemController: StatusItemController?

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            statusItemController = StatusItemController(model: AppModel.shared)
            AppModel.shared.bootstrap()
        }
    }
}

@main
struct GesturesApp: App {
    @NSApplicationDelegateAdaptor(GesturesAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
