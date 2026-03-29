import AppKit
import Foundation
import GesturesCore

struct DetectedGestureEntry: Identifiable {
    let id = UUID()
    let kind: GestureKind
    let detectedAt: Date
    let detail: String
}

private enum HapticFeedbackKind {
    case trigger
    case ready

    var debugName: String {
        switch self {
        case .trigger:
            "trigger"
        case .ready:
            "ready"
        }
    }
}

protocol GestureHapticPerforming {
    func performTrigger()
    func performReady()
}

struct SystemGestureHapticPerformer: GestureHapticPerforming {
    func performTrigger() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    func performReady() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.generic, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private static let debugModeDefaultsKey = "debugModeEnabled"

    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var isCaptureRunning = false
    @Published private(set) var captureMessage = "Starting…"
    @Published private(set) var isDebugModeEnabled = false
    @Published private(set) var isLaunchAtLoginEnabled = false
    @Published private(set) var launchAtLoginErrorMessage: String?
    @Published private(set) var lastGesture: GestureEvent?
    @Published private(set) var lastGestureObservedAt: Date?
    @Published private(set) var recentDetections: [DetectedGestureEntry] = []
    @Published private(set) var captureDiagnostics = CaptureDiagnostics()
    @Published private(set) var debugLogPath: String

    let store = GestureBindingStore()

    private let clickSuppressor: ClickSuppressor
    private let dispatcher: ShortcutDispatching
    private let hapticPerformer: GestureHapticPerforming
    private let service: MultitouchService
    private let accessibilityController: AccessibilityAccessController
    private let launchAtLoginController: LaunchAtLoginController
    private let debugLog: DebugLogActions
    private let userDefaults: UserDefaults
    private var hasBootstrapped = false

    private init(
        dispatcher: ShortcutDispatching? = nil,
        hapticPerformer: GestureHapticPerforming = SystemGestureHapticPerformer(),
        service: MultitouchService = MultitouchService(),
        debugLogWriter: DebugLogWriter = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        let isDebugModeEnabled = userDefaults.bool(forKey: Self.debugModeDefaultsKey)
        let debugLog = DebugLogActions(writer: debugLogWriter)
        self.accessibilityController = AccessibilityAccessController()
        self.launchAtLoginController = LaunchAtLoginController()
        self.debugLog = debugLog
        self.userDefaults = userDefaults
        self.isDebugModeEnabled = isDebugModeEnabled
        debugLog.setLoggingEnabled(isDebugModeEnabled)
        self.clickSuppressor = ClickSuppressor(logger: { message in
            debugLogWriter.append(message)
        })
        self.dispatcher = dispatcher ?? ShortcutDispatcher(logger: { message in
            debugLogWriter.append(message)
        })
        self.hapticPerformer = hapticPerformer
        self.service = service
        self.service.clickSuppressor = clickSuppressor
        debugLogPath = debugLog.logFilePath

        service.onGesture = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        service.onFrame = { [weak self] frame in
            Task { @MainActor [weak self] in
                self?.logFrame(frame)
            }
        }
        service.onDiagnostics = { [weak self] diagnostics in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isDebugModeEnabled else { return }
                self.captureDiagnostics = diagnostics
                self.logDiagnostics(diagnostics)
            }
        }
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        debugLog.append("Application bootstrapping")
        refreshAccessibilityStatus()
        refreshLaunchAtLoginStatus()
        restartCapture()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = accessibilityController.refreshStatus()
    }

    func requestAccessibilityAccess() {
        debugLog.append("Prompting for Accessibility access")
        isAccessibilityTrusted = accessibilityController.requestAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    func openAccessibilitySettings() {
        accessibilityController.openSettings()
    }

    func restartCapture() {
        captureMessage = "Starting capture…"
        isCaptureRunning = false
        debugLog.append("Restarting capture")
        service.stop()
        clickSuppressor.start()
        let started = service.start()
        isCaptureRunning = started
        captureMessage = started
            ? "Capture is running for available trackpads."
            : (service.lastErrorMessage ?? "Capture could not be started.")
        debugLog.append("Capture start result: \(captureMessage)")
    }

    func resetDefaults() {
        store.resetToDefaults()
        debugLog.append("Reset bindings to defaults")
    }

    func openDebugLog() {
        debugLog.openLog()
    }

    func revealDebugLogInFinder() {
        debugLog.revealLogInFinder()
    }

    func clearDebugLog() {
        debugLog.clearLog()
    }

    func copyDebugLogPath() {
        debugLog.copyLogPath()
    }

    func refreshLaunchAtLoginStatus() {
        isLaunchAtLoginEnabled = launchAtLoginController.refreshStatus()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(isEnabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }

    func clearLaunchAtLoginError() {
        launchAtLoginErrorMessage = nil
    }

    func testTriggerHaptic() {
        playHaptic(.trigger, source: "manual test")
        captureMessage = "Played trigger haptic test."
    }

    func testReadyHaptic() {
        playHaptic(.ready, source: "manual test")
        captureMessage = "Played ready haptic test."
    }

    func setDebugModeEnabled(_ isEnabled: Bool) {
        guard isDebugModeEnabled != isEnabled else { return }
        isDebugModeEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: Self.debugModeDefaultsKey)
        debugLog.setLoggingEnabled(isEnabled)

        if isEnabled {
            debugLog.append("Debug mode enabled")
            refreshAccessibilityStatus()
            if isCaptureRunning {
                restartCapture()
            }
        } else {
            clearDebugState()
            if isCaptureRunning {
                restartCapture()
            }
        }
    }

    private func handle(_ event: GestureEvent) {
        if isDebugModeEnabled {
            lastGesture = event
            lastGestureObservedAt = Date()
        }
        let configuration = store.binding(for: event.kind)

        if event.phase == .armed {
            guard configuration.isEnabled else { return }
            if configuration.isHapticsEnabled && event.shouldPlayHaptic {
                playHaptic(.ready, source: "\(event.kind.displayName) armed")
            }
            captureMessage = "\(event.kind.displayName) is ready; lift to trigger."
            if isDebugModeEnabled {
                recordDetection(kind: event.kind, detail: "Ready; lift to trigger")
                debugLog.append("Gesture armed: \(event.kind.displayName)")
            }
            return
        }

        guard configuration.isEnabled else {
            captureMessage = "Detected \(event.kind.displayName), but its mapping is disabled."
            if isDebugModeEnabled {
                recordDetection(kind: event.kind, detail: "Detected only; mapping disabled")
                debugLog.append("Gesture detected: \(event.kind.displayName) | mapping disabled")
            }
            return
        }

        let dispatched = dispatcher.dispatch(configuration.action)
        let actionDescription = configuration.action.displayString
        if dispatched {
            if configuration.isHapticsEnabled && event.shouldPlayHaptic {
                playHaptic(.trigger, source: "\(event.kind.displayName) recognized")
            }
            captureMessage = "Triggered \(event.kind.displayName) → \(actionDescription)"
            if isDebugModeEnabled {
                recordDetection(kind: event.kind, detail: "Sent \(actionDescription)")
                let hapticsSuffix = configuration.isHapticsEnabled && event.shouldPlayHaptic ? " | haptics played" : ""
                debugLog.append("Gesture detected: \(event.kind.displayName) | dispatched \(actionDescription)\(hapticsSuffix)")
            }
        } else {
            refreshAccessibilityStatus()
            captureMessage = "Gesture detected, but Accessibility access is still required to send actions."
            if isDebugModeEnabled {
                recordDetection(kind: event.kind, detail: "Detected only; shortcut dispatch blocked")
                debugLog.append("Gesture detected: \(event.kind.displayName) | dispatch blocked")
            }
        }
    }

    private func recordDetection(kind: GestureKind, detail: String) {
        recentDetections.insert(
            DetectedGestureEntry(kind: kind, detectedAt: Date(), detail: detail),
            at: 0
        )
        if recentDetections.count > 12 {
            recentDetections.removeLast(recentDetections.count - 12)
        }
    }

    private func logFrame(_ frame: TouchFrame) {
        guard isDebugModeEnabled else { return }
        let summary = frame.contacts.isEmpty
            ? "0 contacts"
            : frame.contacts
                .sorted { $0.identifier < $1.identifier }
                .map { contact in
                    let x = String(format: "%.2f", contact.position.x)
                    let y = String(format: "%.2f", contact.position.y)
                    return "#\(contact.identifier) \(contact.phase.debugLabel) (\(x), \(y))"
                }
                .joined(separator: " | ")
        debugLog.append("Frame: \(summary)")
    }

    private func logDiagnostics(_ diagnostics: CaptureDiagnostics) {
        guard isDebugModeEnabled else { return }
        debugLog.append(
            """
            Diagnostics: framework=\(diagnostics.frameworkLoaded ? "loaded" : "unavailable"), \
            enumerated=\(diagnostics.enumeratedDeviceCount), \
            started=\(diagnostics.startedDeviceCount), \
            registered=\(diagnostics.successfulRegistrationCount), \
            callbacks=\(diagnostics.callbackCount), \
            status=\"\(diagnostics.statusSummary)\"
            """
        )
    }

    private func playHaptic(_ kind: HapticFeedbackKind, source: String) {
        switch kind {
        case .trigger:
            hapticPerformer.performTrigger()
        case .ready:
            hapticPerformer.performReady()
        }

        if isDebugModeEnabled {
            debugLog.append("Haptic request: kind=\(kind.debugName) source=\(source)")
        }
    }

    private func clearDebugState() {
        lastGesture = nil
        lastGestureObservedAt = nil
        recentDetections = []
        captureDiagnostics = CaptureDiagnostics()
    }

    func showAboutPanel() {
        AboutPanelPresenter.show()
    }

    var supportsLaunchAtLogin: Bool {
        launchAtLoginController.isSupported
    }
}

private extension TouchPhase {
    var debugLabel: String {
        switch self {
        case .notTracking:
            "notTracking"
        case .startInRange:
            "startInRange"
        case .hoverInRange:
            "hover"
        case .makeTouch:
            "makeTouch"
        case .touching:
            "touching"
        case .breakTouch:
            "breakTouch"
        case .lingerInRange:
            "linger"
        case .outOfRange:
            "outOfRange"
        }
    }
}
