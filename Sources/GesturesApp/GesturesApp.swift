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
                .frame(width: 320)
                .padding(14)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(model: model, store: model.store)
                .frame(width: 640, height: 500)
        }
        .defaultSize(width: 640, height: 500)
    }
}
