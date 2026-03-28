import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button {
                AppNavigation.activate()
                openSettings()
            } label: {
                Label("Settings\u{2026}", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Label(
                model.isCaptureRunning ? "Capture Running" : "Capture Stopped",
                systemImage: model.isCaptureRunning ? "wave.3.right.circle.fill" : "pause.circle"
            )

            Label(
                model.isAccessibilityTrusted ? "Accessibility Granted" : "Accessibility Required",
                systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
            )

            Text(model.captureMessage)
                .foregroundStyle(.secondary)

            Divider()

            if !model.isAccessibilityTrusted {
                Button("Grant Accessibility Access") {
                    model.requestAccessibilityAccess()
                }

                Button("Open Accessibility Settings") {
                    model.openAccessibilitySettings()
                }
            }

            Button("Restart Capture") {
                model.restartCapture()
            }

            Divider()

            Button {
                AppNavigation.activate()
                openWindow(id: AppWindowID.troubleshooting)
            } label: {
                Label("Troubleshooting\u{2026}", systemImage: "stethoscope")
            }

            Button {
                model.showAboutPanel()
            } label: {
                Label("About Gestures", systemImage: "info.circle")
            }

            Button("Quit Gestures") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
