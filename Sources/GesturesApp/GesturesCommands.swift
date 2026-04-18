import SwiftUI

struct GesturesCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        let _ = SettingsSceneBridge.shared.register(openSettings)

        CommandGroup(replacing: .appInfo) {
            Button("About Gestures") {
                model.showAboutPanel()
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                AppNavigation.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("Gestures") {
            Button("Restart Capture") {
                model.restartCapture()
            }

            if !model.isAccessibilityTrusted {
                Button("Grant Accessibility Access") {
                    model.requestAccessibilityAccess()
                }

                Button("Open Accessibility Settings") {
                    model.openAccessibilitySettings()
                }
            }
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Gestures") {
                AppNavigation.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
