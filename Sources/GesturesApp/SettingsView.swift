import GesturesCore
import SwiftUI

private enum SettingsPane: Hashable {
    case general
    case gestures
    case advanced
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: GestureBindingStore
    @Environment(\.openWindow) private var openWindow

    @State private var selectedPane: SettingsPane = .general
    @State private var showsResetDefaultsConfirmation = false

    var body: some View {
        TabView(selection: $selectedPane) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsPane.general)

            gesturesTab
                .tabItem {
                    Label("Gestures", systemImage: "hand.tap")
                }
                .tag(SettingsPane.gestures)

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
                .tag(SettingsPane.advanced)
        }
        .confirmationDialog(
            "Reset All Gesture Defaults?",
            isPresented: $showsResetDefaultsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Defaults", role: .destructive) {
                model.resetDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores every gesture mapping to its default action.")
        }
        .alert(
            "Launch at Login Couldn’t Be Changed",
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

    private var generalTab: some View {
        SettingsPaneContainer(width: 560, height: 380) {
            PreferenceSection("Permissions") {
                PreferenceRow("Accessibility") {
                    Label(
                        model.isAccessibilityTrusted ? "Granted" : "Required",
                        systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                    )
                    .foregroundStyle(model.isAccessibilityTrusted ? .green : .primary)
                }

                PreferenceRow {
                    Text("Gestures needs Accessibility permission to send keyboard shortcuts and pointer actions.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PreferenceRow {
                    HStack(spacing: 12) {
                        Button("Open Accessibility Settings") {
                            model.openAccessibilitySettings()
                        }

                        if !model.isAccessibilityTrusted {
                            Button("Grant Access") {
                                model.requestAccessibilityAccess()
                            }
                        }

                        Button("Check Again") {
                            model.refreshAccessibilityStatus()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            PreferenceSection("Startup") {
                PreferenceRow {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { model.isLaunchAtLoginEnabled },
                            set: { model.setLaunchAtLoginEnabled($0) }
                        )
                    )
                    .disabled(!model.supportsLaunchAtLogin)
                }

                if !model.supportsLaunchAtLogin {
                    PreferenceRow {
                        Text("This option is available in the bundled app build.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            PreferenceSection("Support") {
                PreferenceRow {
                    HStack(spacing: 12) {
                        Button("Open Troubleshooting…") {
                            openWindow(id: AppWindowID.troubleshooting)
                        }

                        Button("About Gestures") {
                            model.showAboutPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var gesturesTab: some View {
        SettingsPaneContainer(width: 620, height: 560) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(GestureKind.allCases.enumerated()), id: \.element) { index, gesture in
                let configuration = store.binding(for: gesture)

                    PreferenceSection(gesture.displayName) {
                        PreferenceRow {
                            Text(gesture.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        PreferenceRow {
                            Toggle(
                                "Enable this gesture",
                                isOn: Binding(
                                    get: { configuration.isEnabled },
                                    set: { store.setEnabled($0, for: gesture) }
                                )
                            )
                        }

                        PreferenceRow("Action") {
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
                            .labelsHidden()
                            .frame(width: 220, alignment: .leading)
                        }

                        switch configuration.action {
                        case let .keyboardShortcut(shortcut):
                            PreferenceRow("Shortcut") {
                                ShortcutRecorder(shortcut: shortcut) { newShortcut in
                                    store.updateShortcut(newShortcut, for: gesture)
                                }
                            }
                        case .middleClick:
                            PreferenceRow("Output") {
                                Text("Middle mouse button")
                            }
                        }
                    }

                    if index < GestureKind.allCases.count - 1 {
                        Divider()
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button("Reset All Gesture Defaults…", role: .destructive) {
                        showsResetDefaultsConfirmation = true
                    }
                }
            }
        }
    }

    private var advancedTab: some View {
        SettingsPaneContainer(width: 540, height: 280) {
            PreferenceSection("Debugging") {
                PreferenceRow {
                    Toggle(
                        "Enable debug mode",
                        isOn: Binding(
                            get: { model.isDebugModeEnabled },
                            set: { model.setDebugModeEnabled($0) }
                        )
                    )
                }

                PreferenceRow {
                    Text("Debug mode keeps recent gesture history and writes a diagnostic log to disk.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            PreferenceSection("Diagnostics") {
                PreferenceRow {
                    HStack(spacing: 12) {
                        Button("Open Troubleshooting…") {
                            openWindow(id: AppWindowID.troubleshooting)
                        }

                        if model.isDebugModeEnabled {
                            Button("Open Log") {
                                model.openDebugLog()
                            }

                            Button("Reveal Log in Finder") {
                                model.revealDebugLogInFinder()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct SettingsPaneContainer<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.headline)
                .frame(width: 140, alignment: .trailing)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PreferenceRow<Content: View>: View {
    let label: String?
    @ViewBuilder let content: Content

    init(_ label: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            if let label {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 140)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
