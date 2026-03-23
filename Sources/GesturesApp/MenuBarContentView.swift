import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gestures")
                .font(.title3.weight(.semibold))

            statusRow(title: "Accessibility", value: model.isAccessibilityTrusted ? "Granted" : "Required")
            statusRow(title: "Capture", value: model.isCaptureRunning ? "Running" : "Stopped")

            if let lastGesture = model.lastGesture {
                statusRow(title: "Last Gesture", value: lastGesture.kind.displayName)
                statusRow(
                    title: "At",
                    value: model.lastGestureObservedAt?.formatted(.dateTime.hour().minute().second()) ?? "Just now"
                )
            }

            Text(model.captureMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Open Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

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

    @ViewBuilder
    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}
