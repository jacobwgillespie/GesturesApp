import AppKit
import GesturesCore
import SwiftUI

private enum SettingsPane: Hashable {
    case general
    case gestures
    case advanced

    var title: String {
        switch self {
        case .general:
            "General"
        case .gestures:
            "Gestures"
        case .advanced:
            "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .gestures:
            "hand.tap"
        case .advanced:
            "wrench.and.screwdriver"
        }
    }
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
    @State private var paneHistory: [SettingsPane] = [.general]
    @State private var paneHistoryIndex = 0
    @State private var isRestoringPaneFromHistory = false
    @State private var showsResetDefaultsConfirmation = false

    init(model: AppModel) {
        self.model = model
        _store = ObservedObject(wrappedValue: model.store)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                SettingsPaneRow(pane: .general)
                SettingsPaneRow(pane: .gestures)
                SettingsPaneRow(pane: .advanced)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            VStack(spacing: 0) {
                SettingsDetailHeader(
                    title: selectedPane.title,
                    canGoBack: paneHistoryIndex > 0,
                    canGoForward: paneHistoryIndex < paneHistory.count - 1,
                    goBack: goBack,
                    goForward: goForward
                )

                selectedPaneContent
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .controlSize(.regular)
        .frame(width: 760, height: 520)
        .background(SettingsWindowConfigurator(refreshTrigger: selectedPane))
        .onChange(of: selectedPane) { _, newPane in
            recordPaneSelection(newPane)
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

    private func recordPaneSelection(_ pane: SettingsPane) {
        guard !isRestoringPaneFromHistory else {
            isRestoringPaneFromHistory = false
            return
        }

        guard paneHistory[paneHistoryIndex] != pane else { return }

        if paneHistoryIndex < paneHistory.count - 1 {
            paneHistory.removeSubrange((paneHistoryIndex + 1)..<paneHistory.count)
        }

        paneHistory.append(pane)
        paneHistoryIndex = paneHistory.count - 1
    }

    private func goBack() {
        guard paneHistoryIndex > 0 else { return }
        paneHistoryIndex -= 1
        isRestoringPaneFromHistory = true
        selectedPane = paneHistory[paneHistoryIndex]
    }

    private func goForward() {
        guard paneHistoryIndex < paneHistory.count - 1 else { return }
        paneHistoryIndex += 1
        isRestoringPaneFromHistory = true
        selectedPane = paneHistory[paneHistoryIndex]
    }

    @ViewBuilder
    private var selectedPaneContent: some View {
        switch selectedPane {
        case .general:
            generalTab
        case .gestures:
            gesturesTab
        case .advanced:
            advancedTab
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

private struct SettingsPaneRow: View {
    let pane: SettingsPane

    var body: some View {
        NavigationLink(value: pane) {
            Label(pane.title, systemImage: pane.systemImage)
        }
    }
}

private struct SettingsDetailHeader: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let goBack: () -> Void
    let goForward: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ControlGroup {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                .help("Back")

                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                .help("Forward")
            }
            .controlSize(.large)

            Text(title)
                .font(.title2.weight(.semibold))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    // Recreate/update the representable after pane selection, when SwiftUI may restore the Settings window title.
    let refreshTrigger: SettingsPane

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configure(nsView.window)
        }
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }

        applySettingsChrome(to: window)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            applySettingsChrome(to: window)
        }
    }

    private static func applySettingsChrome(to window: NSWindow) {
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        removeSidebarToggle(from: window.toolbar)
        insetTrafficLightButtons(in: window)
    }

    private static func removeSidebarToggle(from toolbar: NSToolbar?) {
        guard let toolbar else { return }

        for index in toolbar.items.indices.reversed() {
            let identifier = toolbar.items[index].itemIdentifier.rawValue.lowercased()
            if identifier.contains("sidebar") {
                toolbar.removeItem(at: index)
            }
        }
    }

    private static func insetTrafficLightButtons(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }
        guard let closeButton = buttons.first else { return }

        let targetCloseX: CGFloat = 18
        let offset = targetCloseX - closeButton.frame.minX
        guard abs(offset) > 0.5 else { return }

        for button in buttons {
            button.setFrameOrigin(NSPoint(x: button.frame.origin.x + offset, y: button.frame.origin.y))
        }
    }
}
