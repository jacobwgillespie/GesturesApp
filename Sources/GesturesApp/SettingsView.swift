import GesturesCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: GestureBindingStore

    var body: some View {
        TabView {
            SettingsScrollView {
                SettingsSection("Overview") {
                    Text("Gestures is a direct-download utility that listens to trackpad touch data globally and translates recognized gestures into actions such as keyboard shortcuts or a middle click.")
                    Text("Action dispatch requires Accessibility access. Gesture suppression is best effort only and may vary by macOS version.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Label(
                            model.isAccessibilityTrusted ? "Accessibility granted" : "Accessibility required",
                            systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                        )
                        Spacer()
                        Button("Grant Access") {
                            model.requestAccessibilityAccess()
                        }
                    }
                }

                SettingsSection("Capture") {
                    settingsRow("Capture", value: model.isCaptureRunning ? "Running" : "Stopped")

                    if let lastGesture = model.lastGesture {
                        settingsRow("Last Gesture", value: lastGesture.kind.displayName)
                        settingsRow(
                            "Last Seen",
                            value: model.lastGestureObservedAt?.formatted(.dateTime.hour().minute().second()) ?? "Just now"
                        )
                    }

                    Text(model.captureMessage)
                        .foregroundStyle(.secondary)
                }

                SettingsSection("Controls") {
                    HStack {
                        Button("Restart Capture") {
                            model.restartCapture()
                        }
                        Button("Reset Defaults") {
                            model.resetDefaults()
                        }
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            SettingsScrollView {
                SettingsSection("Gesture Bindings") {
                    ForEach(GestureKind.allCases) { gesture in
                        let configuration = store.binding(for: gesture)

                        VStack(alignment: .leading, spacing: 12) {
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
                                .frame(width: 190)
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
                                settingsRow("Output", value: "Middle mouse button")
                            }
                        }
                        .padding(.vertical, 8)

                        if gesture != GestureKind.allCases.last {
                            Divider()
                        }
                    }
                }
            }
            .tabItem {
                Label("Gestures", systemImage: "hand.tap")
            }

            SettingsScrollView {
                SettingsSection("Debug Mode") {
                    Toggle(
                        "Enable debug mode",
                        isOn: Binding(
                            get: { model.isDebugModeEnabled },
                            set: { model.setDebugModeEnabled($0) }
                        )
                    )

                    Text("When disabled, Gestures stops writing the debug log and does not keep gesture history or capture diagnostics in the UI.")
                        .foregroundStyle(.secondary)
                }

                if model.isDebugModeEnabled {
                    SettingsSection("Capture Diagnostics") {
                        settingsRow("Framework", value: model.captureDiagnostics.frameworkLoaded ? "Loaded" : "Unavailable")
                        settingsRow("Enumerated Devices", value: "\(model.captureDiagnostics.enumeratedDeviceCount)")
                        settingsRow("Started Devices", value: "\(model.captureDiagnostics.startedDeviceCount)")
                        settingsRow("Registered Callbacks", value: "\(model.captureDiagnostics.successfulRegistrationCount)")
                        settingsRow("Callback Count", value: "\(model.captureDiagnostics.callbackCount)")
                        settingsRow(
                            "Last Callback",
                            value: model.captureDiagnostics.lastCallbackAt?.formatted(.dateTime.hour().minute().second()) ?? "Never"
                        )

                        Text(model.captureDiagnostics.statusSummary)
                            .foregroundStyle(.secondary)
                    }

                    SettingsSection("Detected Gestures") {
                        if model.recentDetections.isEmpty {
                            Text("No gestures detected yet. Use this view to confirm capture is working before testing action dispatch.")
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

                    SettingsSection("Debug Log") {
                        Text("High-volume touch diagnostics are written to disk instead of rendering live in settings.")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.debugLogPath)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)

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
                    }
                } else {
                    SettingsSection("Advanced Tools") {
                        Text("Enable debug mode to view capture diagnostics, recent detected gestures, and the debug log.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tabItem {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func settingsRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SettingsScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
