import SwiftUI

struct TroubleshootingView: View {
    @ObservedObject var model: AppModel

    @State private var showsClearLogConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusSection
                hapticsSection

                if model.isDebugModeEnabled {
                    diagnosticsSection
                    detectedGesturesSection
                    debugLogSection
                } else {
                    Text("Enable debug mode in Settings \u{2192} Advanced for capture diagnostics and gesture history.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 620, minHeight: 400)
        .alert(
            "Clear Debug Log?",
            isPresented: $showsClearLogConfirmation
        ) {
            Button("Clear Log", role: .destructive) {
                model.clearDebugLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the current diagnostic log file contents.")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Capture") {
                    Text(model.isCaptureRunning ? "Running" : "Stopped")
                }

                LabeledContent("Accessibility") {
                    Label(
                        model.isAccessibilityTrusted ? "Granted" : "Required",
                        systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                    )
                    .foregroundStyle(model.isAccessibilityTrusted ? .green : .primary)
                }

                if let lastGesture = model.lastGesture {
                    LabeledContent("Last Gesture") {
                        Text(lastGesture.kind.displayName)
                    }
                }

                if let lastGestureObservedAt = model.lastGestureObservedAt {
                    LabeledContent("Last Seen") {
                        Text(lastGestureObservedAt.formatted(.dateTime.hour().minute().second()))
                    }
                }

                Text(model.captureMessage)
                    .foregroundStyle(.secondary)

                HStack {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var hapticsSection: some View {
        GroupBox("Haptics") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use these buttons to verify whether Gestures can request trackpad haptics independently of gesture detection.")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Test Trigger Haptic") {
                        model.testTriggerHaptic()
                    }

                    Button("Test Ready Haptic") {
                        model.testReadyHaptic()
                    }
                }

                if model.isDebugModeEnabled {
                    Text("When debug mode is enabled, each attempt is also written to the debug log.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        GroupBox("Capture Diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Framework") {
                    Text(model.captureDiagnostics.frameworkLoaded ? "Loaded" : "Unavailable")
                }
                LabeledContent("Enumerated Devices") {
                    Text("\(model.captureDiagnostics.enumeratedDeviceCount)")
                }
                LabeledContent("Started Devices") {
                    Text("\(model.captureDiagnostics.startedDeviceCount)")
                }
                LabeledContent("Registered Callbacks") {
                    Text("\(model.captureDiagnostics.successfulRegistrationCount)")
                }
                LabeledContent("Callback Count") {
                    Text("\(model.captureDiagnostics.callbackCount)")
                }
                LabeledContent("Last Callback") {
                    Text(
                        model.captureDiagnostics.lastCallbackAt?.formatted(.dateTime.hour().minute().second())
                            ?? "Never"
                    )
                }

                Text(model.captureDiagnostics.statusSummary)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var detectedGesturesSection: some View {
        GroupBox("Detected Gestures") {
            if model.recentDetections.isEmpty {
                Text("Perform a gesture to confirm capture is working.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                Table(model.recentDetections) {
                    TableColumn("Gesture") { detection in
                        Text(detection.kind.displayName)
                    }
                    .width(min: 180)

                    TableColumn("Time") { detection in
                        Text(detection.detectedAt.formatted(.dateTime.hour().minute().second()))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 110)

                    TableColumn("Result") { detection in
                        Text(detection.detail)
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    @ViewBuilder
    private var debugLogSection: some View {
        GroupBox("Debug Log") {
            VStack(alignment: .leading, spacing: 12) {
                Text("High-volume touch diagnostics are written to disk to keep this window responsive.")
                    .foregroundStyle(.secondary)

                Text(model.debugLogPath)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .draggable(URL(fileURLWithPath: model.debugLogPath))
                    .contextMenu {
                        Button("Copy Path") {
                            model.copyDebugLogPath()
                        }
                    }

                HStack {
                    Button("Open Log") {
                        model.openDebugLog()
                    }
                    Button("Reveal in Finder") {
                        model.revealDebugLogInFinder()
                    }
                    Spacer()
                    Button("Clear Log", role: .destructive) {
                        showsClearLogConfirmation = true
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
