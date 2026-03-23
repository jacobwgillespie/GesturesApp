import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Open Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

            Divider()

            Text("Capture: \(model.isCaptureRunning ? "Running" : "Stopped")")
            Text("Accessibility: \(model.isAccessibilityTrusted ? "Granted" : "Required")")

            if let lastGesture = model.lastGesture {
                Text("Last Gesture: \(lastGesture.kind.displayName)")
            }

            Text(model.captureMessage)

            Divider()

            Button("Grant Accessibility Access") {
                model.requestAccessibilityAccess()
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
