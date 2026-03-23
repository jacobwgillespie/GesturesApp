import AppKit
import SwiftUI

@main
struct GesturesApp: App {
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
            SettingsView(model: model, store: model.store)
        }
        .windowResizability(.contentSize)

        Window("Troubleshooting", id: AppWindowID.troubleshooting) {
            TroubleshootingView(model: model)
        }
        .defaultSize(width: 720, height: 620)
        .windowResizability(.contentMinSize)
    }
}
