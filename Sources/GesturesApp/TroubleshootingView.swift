import SwiftUI

struct TroubleshootingView: View {
    @ObservedObject var model: AppModel

    @State private var showsClearLogConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
                diagnosticsSection
                detectedGesturesSection
                debugLogSection
            }
            .padding(20)
        }
        .frame(minWidth: 680, minHeight: 560)
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
    private var diagnosticsSection: some View {
        if model.isDebugModeEnabled {
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
        } else {
            ContentUnavailableView(
                "Debug Diagnostics Are Off",
                systemImage: "ladybug.slash",
                description: Text("Enable debug mode in Settings to capture gesture history and low-level diagnostics.")
            )
        }
    }

    @ViewBuilder
    private var detectedGesturesSection: some View {
        if model.isDebugModeEnabled {
            GroupBox("Detected Gestures") {
                if model.recentDetections.isEmpty {
                    ContentUnavailableView(
                        "No Gestures Detected Yet",
                        systemImage: "hand.tap",
                        description: Text("Use this window while testing a gesture to confirm capture is working.")
                    )
                    .frame(maxWidth: .infinity)
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
                    .frame(minHeight: 220)
                }
            }
        }
    }

    @ViewBuilder
    private var debugLogSection: some View {
        if model.isDebugModeEnabled {
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
                            Button("Open Log") {
                                model.openDebugLog()
                            }
                            Button("Reveal in Finder") {
                                model.revealDebugLogInFinder()
                            }
                        }

                    HStack {
                        Button("Copy Path") {
                            model.copyDebugLogPath()
                        }
                        Button("Open Log") {
                            model.openDebugLog()
                        }
                        Button("Reveal in Finder") {
                            model.revealDebugLogInFinder()
                        }
                        Button("Clear Log", role: .destructive) {
                            showsClearLogConfirmation = true
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
