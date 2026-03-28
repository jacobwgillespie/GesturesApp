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
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow(alignment: .firstTextBaseline) {
                Text("Accessibility:")
                    .gridColumnAlignment(.trailing)

                Label(
                    model.isAccessibilityTrusted ? "Granted" : "Required",
                    systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
                )
                .foregroundStyle(model.isAccessibilityTrusted ? .green : .primary)
                .gridColumnAlignment(.leading)
            }

            GridRow {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])

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
            }

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { model.isLaunchAtLoginEnabled },
                set: { model.setLaunchAtLoginEnabled($0) }
            ))
            .disabled(!model.supportsLaunchAtLogin)

            if !model.supportsLaunchAtLogin {
                Text("This option is available in the bundled app build.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Open Troubleshooting…") {
                    openWindow(id: AppWindowID.troubleshooting)
                }

                Button("About Gestures") {
                    model.showAboutPanel()
                }
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    // MARK: - Gestures

    private var gesturesTab: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(GestureKind.allCases) { gesture in
                let configuration = store.binding(for: gesture)

                Text(gesture.displayName)
                    .font(.headline)
                    .padding(.top, 2)

                Text(gesture.detail)
                    .foregroundStyle(.secondary)

                Toggle("Enabled", isOn: Binding(
                    get: { configuration.isEnabled },
                    set: { store.setEnabled($0, for: gesture) }
                ))

                Toggle("Haptic feedback", isOn: Binding(
                    get: { configuration.isHapticsEnabled },
                    set: { store.setHapticsEnabled($0, for: gesture) }
                ))

                GridRow(alignment: .firstTextBaseline) {
                    Text("Action:")
                        .gridColumnAlignment(.trailing)

                    Picker("Action", selection: Binding(
                        get: { configuration.action.kind },
                        set: { store.updateActionKind($0, for: gesture) }
                    )) {
                        ForEach(GestureActionKind.allCases) { actionKind in
                            Text(actionKind.displayName).tag(actionKind)
                        }
                    }
                    .labelsHidden()
                    .gridColumnAlignment(.leading)
                }

                switch configuration.action {
                case let .keyboardShortcut(shortcut):
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Shortcut:")
                        ShortcutRecorder(shortcut: shortcut) { newShortcut in
                            store.updateShortcut(newShortcut, for: gesture)
                        } onDelete: {
                            store.updateShortcut(gesture.defaultShortcutBinding, for: gesture)
                        }
                    }
                case .middleClick:
                    GridRow(alignment: .firstTextBaseline) {
                        Text("Output:")
                        Text("Middle mouse button")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
            }

            HStack {
                Spacer()
                Button("Reset All Gesture Defaults…", role: .destructive) {
                    showsResetDefaultsConfirmation = true
                }
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            Toggle("Enable debug mode", isOn: Binding(
                get: { model.isDebugModeEnabled },
                set: { model.setDebugModeEnabled($0) }
            ))

            Text("Debug mode keeps recent gesture history and writes a diagnostic log to disk.")
                .foregroundStyle(.secondary)

            Divider()

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
        }
        .padding(20)
        .frame(width: 500)
    }
}
