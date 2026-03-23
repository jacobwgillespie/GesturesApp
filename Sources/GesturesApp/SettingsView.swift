import GesturesCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: GestureBindingStore

    var body: some View {
        Form {
            Section("Onboarding") {
                Text("Gestures is a direct-download utility that listens to trackpad touch data globally and translates recognized gestures into actions such as keyboard shortcuts or a middle click.")
                Text("Action dispatch requires Accessibility access. Gesture suppression is best effort only and may vary by macOS version.")
                    .foregroundStyle(.secondary)

                HStack {
                    Label(model.isAccessibilityTrusted ? "Accessibility granted" : "Accessibility required", systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield")
                    Spacer()
                    Button("Grant Access") {
                        model.requestAccessibilityAccess()
                    }
                }
            }

            Section("Status") {
                LabeledContent("Capture") {
                    Text(model.isCaptureRunning ? "Running" : "Stopped")
                }
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
                    Text(model.captureDiagnostics.lastCallbackAt?.formatted(.dateTime.hour().minute().second()) ?? "Never")
                }

                if let lastGesture = model.lastGesture {
                    LabeledContent("Last Gesture") {
                        Text(lastGesture.kind.displayName)
                    }
                    LabeledContent("Timestamp") {
                        Text(model.lastGestureObservedAt?.formatted(.dateTime.hour().minute().second()) ?? "Just now")
                    }
                }

                Text(model.captureMessage)
                    .foregroundStyle(.secondary)
                Text(model.captureDiagnostics.statusSummary)
                    .foregroundStyle(.secondary)
            }

            Section("Detected Gestures") {
                if model.recentDetections.isEmpty {
                    Text("No gestures detected yet. Use this list to confirm capture is working before testing shortcut dispatch.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recentDetections) { detection in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(detection.kind.displayName)
                                Spacer()
                                Text(detection.detectedAt.formatted(.dateTime.hour().minute().second()))
                                    .foregroundStyle(.secondary)
                            }
                            Text(detection.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Debug Log") {
                Text("High-volume touch diagnostics are written to disk instead of rendering live in settings.")
                    .foregroundStyle(.secondary)

                LabeledContent("Log Path") {
                    Text(model.debugLogPath)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }

                HStack {
                    Button("Open Log") {
                        model.openDebugLog()
                    }
                    Button("Reveal in Finder") {
                        model.revealDebugLogInFinder()
                    }
                    Button("Clear Log") {
                        model.clearDebugLog()
                    }
                }
            }

            Section("Gesture Bindings") {
                ForEach(GestureKind.allCases) { gesture in
                    let configuration = store.binding(for: gesture)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { configuration.isEnabled },
                            set: { store.setEnabled($0, for: gesture) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gesture.displayName)
                                Text(gesture.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Action")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker(
                                "Action",
                                selection: Binding(
                                    get: { configuration.action.kind },
                                    set: { store.updateActionKind($0, for: gesture) }
                                )
                            ) {
                                ForEach(GestureActionKind.allCases) { actionKind in
                                    Text(actionKind.displayName).tag(actionKind)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        switch configuration.action {
                        case let .keyboardShortcut(shortcut):
                            HStack {
                                Text("Shortcut")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                ShortcutRecorder(shortcut: shortcut) { newShortcut in
                                    store.updateShortcut(newShortcut, for: gesture)
                                }
                            }
                        case .middleClick:
                            HStack {
                                Text("Output")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Middle mouse button")
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Controls") {
                HStack {
                    Button("Reset Defaults") {
                        model.resetDefaults()
                    }

                    Spacer()

                    Button("Restart Capture") {
                        model.restartCapture()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
