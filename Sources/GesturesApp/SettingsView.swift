import GesturesCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: GestureBindingStore
    @Environment(\.openWindow) private var openWindow

    @State private var selectedGesture: GestureKind? = GestureKind.allCases.first
    @State private var showsResetDefaultsConfirmation = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            gesturesTab
                .tabItem {
                    Label("Gestures", systemImage: "hand.tap")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
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
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Label(
                        model.isAccessibilityTrusted ? "Granted" : "Required",
                        systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                    )
                    .foregroundStyle(model.isAccessibilityTrusted ? .green : .primary)
                }

                Text("Gestures needs Accessibility permission to send keyboard shortcuts and pointer actions.")
                    .foregroundStyle(.secondary)

                HStack {
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
            }

            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled },
                        set: { model.setLaunchAtLoginEnabled($0) }
                    )
                )
                .disabled(!model.supportsLaunchAtLogin)

                if !model.supportsLaunchAtLogin {
                    Text("This option is available in the bundled app build.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Support") {
                Button("Open Troubleshooting…") {
                    openWindow(id: AppWindowID.troubleshooting)
                }

                Button("About Gestures") {
                    model.showAboutPanel()
                }
            }
        }
    }

    private var gesturesTab: some View {
        NavigationSplitView {
            List(GestureKind.allCases, selection: $selectedGesture) { gesture in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(gesture.displayName)
                        if !store.binding(for: gesture).isEnabled {
                            Spacer()
                            Text("Off")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(store.binding(for: gesture).action.displayString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .tag(gesture)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            if let selectedGesture {
                gestureDetail(for: selectedGesture)
            } else {
                ContentUnavailableView(
                    "No Gesture Selected",
                    systemImage: "hand.tap",
                    description: Text("Choose a gesture from the list to configure its action.")
                )
            }
        }
    }

    private func gestureDetail(for gesture: GestureKind) -> some View {
        let configuration = store.binding(for: gesture)

        return Form {
            Section {
                Text(gesture.detail)
                    .foregroundStyle(.secondary)
            }

            Section("Mapping") {
                Toggle(
                    "Enable this gesture",
                    isOn: Binding(
                        get: { configuration.isEnabled },
                        set: { store.setEnabled($0, for: gesture) }
                    )
                )

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

                switch configuration.action {
                case let .keyboardShortcut(shortcut):
                    LabeledContent("Shortcut") {
                        ShortcutRecorder(shortcut: shortcut) { newShortcut in
                            store.updateShortcut(newShortcut, for: gesture)
                        }
                    }
                case .middleClick:
                    LabeledContent("Output") {
                        Text("Middle mouse button")
                    }
                }
            }

            Section {
                Button("Reset All Gesture Defaults…", role: .destructive) {
                    showsResetDefaultsConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(gesture.displayName)
    }

    private var advancedTab: some View {
        Form {
            Section("Debugging") {
                Toggle(
                    "Enable debug mode",
                    isOn: Binding(
                        get: { model.isDebugModeEnabled },
                        set: { model.setDebugModeEnabled($0) }
                    )
                )

                Text("Debug mode keeps recent gesture history and writes a diagnostic log to disk.")
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
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
        }
    }
}
