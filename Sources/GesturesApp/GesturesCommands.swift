import SwiftUI

struct GesturesCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Gestures") {
                model.showAboutPanel()
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                AppNavigation.openSettings(using: openSettings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("Gestures") {
            Button("Troubleshooting…") {
                AppNavigation.openTroubleshooting(using: openWindow)
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])

            Divider()

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
