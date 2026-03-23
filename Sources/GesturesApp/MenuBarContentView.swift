import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            Button {
                AppNavigation.activate()
                openWindow(id: AppWindowID.troubleshooting)
            } label: {
                Label("Troubleshooting…", systemImage: "stethoscope")
            }

            Button {
                model.showAboutPanel()
            } label: {
                Label("About Gestures", systemImage: "info.circle")
            }

            Divider()

            Label(
                model.isCaptureRunning ? "Capture Running" : "Capture Stopped",
                systemImage: model.isCaptureRunning ? "wave.3.right.circle.fill" : "pause.circle"
            )

            Label(
                model.isAccessibilityTrusted ? "Accessibility Granted" : "Accessibility Required",
                systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
            )

            if let lastGesture = model.lastGesture {
                Text("Last Gesture: \(lastGesture.kind.displayName)")
            }

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

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
