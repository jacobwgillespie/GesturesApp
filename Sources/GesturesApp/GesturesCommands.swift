import SwiftUI

struct GesturesCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
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
            Button("Troubleshooting…") {
                AppNavigation.activate()
                openWindow(id: AppWindowID.troubleshooting)
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

        CommandGroup(replacing: .help) {
            Button("Gestures Help") {
                AppNavigation.activate()
                openWindow(id: AppWindowID.troubleshooting)
            }

            Button("Accessibility Settings") {
                model.openAccessibilitySettings()
            }
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Gestures") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
