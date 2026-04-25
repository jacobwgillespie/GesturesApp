import GesturesCore
import SwiftUI

private enum SettingsPane: Hashable {
    case general
    case gestures
    case advanced
}

private enum SettingsStatusTone {
    case positive
    case neutral
    case warning

    var foregroundStyle: Color {
        switch self {
        case .positive:
            .green
        case .neutral:
            .secondary
        case .warning:
            .orange
        }
    }
}

private struct SettingsStatusLabel: View {
    let title: String
    let systemImage: String
    let tone: SettingsStatusTone

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone.foregroundStyle)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: GestureBindingStore

    @State private var selectedPane: SettingsPane = .general
    @State private var showsResetDefaultsConfirmation = false

    init(model: AppModel) {
        self.model = model
        _store = ObservedObject(wrappedValue: model.store)
    }

    var body: some View {
        TabView(selection: $selectedPane) {
            Tab("General", systemImage: "gearshape", value: .general) {
                generalTab
            }

            Tab("Gestures", systemImage: "hand.tap", value: .gestures) {
                gesturesTab
            }

            Tab("Advanced", systemImage: "wrench.and.screwdriver", value: .advanced) {
                advancedTab
            }
        }
        .controlSize(.regular)
        .frame(width: 560, height: 520)
        .alert(
            "Reset All Gesture Defaults?",
            isPresented: $showsResetDefaultsConfirmation
        ) {
            Button("Reset Defaults", role: .destructive) {
                model.resetDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores every gesture mapping to its default action.")
        }
        .alert(
            "Launch at Login Couldn't Be Changed",
            isPresented: Binding(
                get: { model.launchAtLoginErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.clearLaunchAtLoginError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.clearLaunchAtLoginError()
            }
        } message: {
            Text(model.launchAtLoginErrorMessage ?? "")
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                LabeledContent("Capture") {
                    SettingsStatusLabel(
                        title: model.isCaptureRunning ? "Running" : "Stopped",
                        systemImage: model.isCaptureRunning ? "wave.3.right.circle.fill" : "pause.circle",
                        tone: model.isCaptureRunning ? .positive : .neutral
                    )
                }

                Text(model.captureMessage)
                    .foregroundStyle(.secondary)

                RestartCaptureButton(model: model)
            }

            Section {
                LabeledContent("Accessibility") {
                    SettingsStatusLabel(
                        title: model.isAccessibilityTrusted ? "Granted" : "Required",
                        systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield",
                        tone: model.isAccessibilityTrusted ? .positive : .warning
                    )
                }

                HStack(spacing: 8) {
                    AccessibilityActionButtons(model: model, showRefreshButton: true)
                }
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.isLaunchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!model.supportsLaunchAtLogin)
            } footer: {
                if !model.supportsLaunchAtLogin {
                    Text("Available in the bundled app build.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Gestures

    private var gesturesTab: some View {
        Form {
            ForEach(GestureKind.allCases) { gesture in
                let configuration = store.binding(for: gesture)

                Section {
                    Toggle("Enabled", isOn: Binding(
                        get: { configuration.isEnabled },
                        set: { store.setEnabled($0, for: gesture) }
                    ))

                    Toggle("Haptic feedback", isOn: Binding(
                        get: { configuration.isHapticsEnabled },
                        set: { store.setHapticsEnabled($0, for: gesture) }
                    ))

                    Picker("Action", selection: Binding(
                        get: { configuration.action.kind },
                        set: { store.updateActionKind($0, for: gesture) }
                    )) {
                        ForEach(GestureActionKind.allCases) { actionKind in
                            Text(actionKind.displayName).tag(actionKind)
                        }
                    }

                    switch configuration.action {
                    case let .keyboardShortcut(shortcut):
                        LabeledContent("Shortcut") {
                            ShortcutRecorder(shortcut: shortcut) { newShortcut in
                                store.updateShortcut(newShortcut, for: gesture)
                            } onDelete: {
                                store.updateShortcut(gesture.defaultShortcutBinding, for: gesture)
                            }
                        }
                    case .middleClick:
                        LabeledContent("Output") {
                            Text("Middle mouse button")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(gesture.displayName)
                } footer: {
                    Text(gesture.detail)
                }
            }

            Section {
                Button(role: .destructive) {
                    showsResetDefaultsConfirmation = true
                } label: {
                    Label("Reset All Gesture Defaults...", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Restores every gesture mapping to its default action.")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section {
                Toggle("Debug mode", isOn: Binding(
                    get: { model.isDebugModeEnabled },
                    set: { model.setDebugModeEnabled($0) }
                ))
            } footer: {
                Text("Keeps recent gesture history and writes a diagnostic log to disk.")
            }

            if model.isDebugModeEnabled {
                Section {
                    Button {
                        model.openDebugLog()
                    } label: {
                        Label("Open Debug Log", systemImage: "doc.text")
                    }

                    Button {
                        model.revealDebugLogInFinder()
                    } label: {
                        Label("Reveal Log in Finder", systemImage: "folder")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
