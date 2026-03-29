import SwiftUI

struct RestartCaptureButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Restart Capture") {
            model.restartCapture()
        }
    }
}

struct AccessibilityActionButtons: View {
    @ObservedObject var model: AppModel
    var showRefreshButton = false

    var body: some View {
        Group {
            if !model.isAccessibilityTrusted {
                Button("Grant Accessibility Access") {
                    model.requestAccessibilityAccess()
                }
            }

            Button("Open Accessibility Settings") {
                model.openAccessibilitySettings()
            }

            if showRefreshButton {
                Button("Check Again") {
                    model.refreshAccessibilityStatus()
                }
            }
        }
    }
}
