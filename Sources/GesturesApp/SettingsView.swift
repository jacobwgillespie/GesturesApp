import GesturesCore
import SwiftUI

private enum SettingsPane: Hashable {
    case general
    case gestures
    case advanced
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: GestureBindingStore
    @Environment(\.openWindow) private var openWindow

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
        .frame(minWidth: 500, idealWidth: 500, maxWidth: 500, minHeight: 420, alignment: .top)
        .onAppear {
            AppNavigation.activate()
        }
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
                LabeledContent("Accessibility") {
                    Label(
                        model.isAccessibilityTrusted ? "Granted" : "Required",
                        systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                    )
                    .foregroundStyle(model.isAccessibilityTrusted ? .green : .primary)
                }

                HStack(spacing: 8) {
                    AccessibilityActionButtons(model: model, showRefreshButton: true)
                }
            } header: {
                Text("Accessibility")
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
    }

    // MARK: - Gestures

    private var gesturesTab: some View {
        VStack(spacing: 0) {
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
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Reset All Gesture Defaults\u{2026}", role: .destructive) {
                    showsResetDefaultsConfirmation = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
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

            Section {
                Button("Open Troubleshooting\u{2026}") {
                    AppNavigation.openTroubleshooting(using: openWindow)
                }

                if model.isDebugModeEnabled {
                    Button("Open Debug Log") {
                        model.openDebugLog()
                    }

                    Button("Reveal Log in Finder") {
                        model.revealDebugLogInFinder()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
