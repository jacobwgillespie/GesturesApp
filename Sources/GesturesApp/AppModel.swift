import AppKit
import Foundation
import GesturesCore

struct CaptureDiagnosticsViewState {
    var frameworkLoaded = false
    var enumeratedDeviceCount = 0
    var startedDeviceCount = 0
    var successfulRegistrationCount = 0
    var callbackCount = 0
    var lastCallbackAt: Date?
    var statusSummary = "Capture has not started."
}

struct DetectedGestureEntry: Identifiable {
    let id = UUID()
    let kind: GestureKind
    let detectedAt: Date
    let detail: String
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var isCaptureRunning = false
    @Published private(set) var captureMessage = "Starting…"
    @Published private(set) var lastGesture: GestureEvent?
    @Published private(set) var lastGestureObservedAt: Date?
    @Published private(set) var recentDetections: [DetectedGestureEntry] = []
    @Published private(set) var captureDiagnostics = CaptureDiagnosticsViewState()
    @Published private(set) var debugLogPath: String

    let store = GestureBindingStore()

    private let dispatcher: ShortcutDispatching
    private let service: MultitouchService
    private let debugLogWriter: DebugLogWriter
    private var hasBootstrapped = false

    private init(
        dispatcher: ShortcutDispatching? = nil,
        service: MultitouchService = MultitouchService(),
        debugLogWriter: DebugLogWriter = .shared
    ) {
        self.debugLogWriter = debugLogWriter
        self.dispatcher = dispatcher ?? ShortcutDispatcher(logger: { message in
            debugLogWriter.append(message)
        })
        self.service = service
        debugLogPath = debugLogWriter.logFileURL.path

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
                let state = CaptureDiagnosticsViewState(
                    frameworkLoaded: diagnostics.frameworkLoaded,
                    enumeratedDeviceCount: diagnostics.enumeratedDeviceCount,
                    startedDeviceCount: diagnostics.startedDeviceCount,
                    successfulRegistrationCount: diagnostics.successfulRegistrationCount,
                    callbackCount: diagnostics.callbackCount,
                    lastCallbackAt: diagnostics.lastCallbackAt,
                    statusSummary: diagnostics.statusSummary
                )
                self?.captureDiagnostics = state
                self?.logDiagnostics(state)
            }
        }
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        debugLogWriter.append("Application bootstrapping")
        refreshAccessibilityStatus()
        restartCapture()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = PermissionsManager.isAccessibilityTrusted(prompt: false)
    }

    func requestAccessibilityAccess() {
        debugLogWriter.append("Prompting for Accessibility access")
        isAccessibilityTrusted = PermissionsManager.isAccessibilityTrusted(prompt: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    func restartCapture() {
        captureMessage = "Starting capture…"
        isCaptureRunning = false
        debugLogWriter.append("Restarting capture")
        service.stop()
        let started = service.start()
        isCaptureRunning = started
        captureMessage = started
            ? "Capture is running for available trackpads."
            : (service.lastErrorMessage ?? "Capture could not be started.")
        debugLogWriter.append("Capture start result: \(captureMessage)")
    }

    func stopCapture() {
        service.stop()
        isCaptureRunning = false
        captureMessage = "Capture is stopped."
        debugLogWriter.append("Capture stopped")
    }

    func resetDefaults() {
        store.resetToDefaults()
        debugLogWriter.append("Reset bindings to defaults")
    }

    func openDebugLog() {
        NSWorkspace.shared.open(debugLogWriter.logFileURL)
    }

    func revealDebugLogInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([debugLogWriter.logFileURL])
    }

    func clearDebugLog() {
        debugLogWriter.clear()
        debugLogWriter.append("Debug log cleared")
    }

    private func handle(_ event: GestureEvent) {
        lastGesture = event
        lastGestureObservedAt = Date()
        let configuration = store.binding(for: event.kind)
        guard configuration.isEnabled else {
            captureMessage = "Detected \(event.kind.displayName), but its mapping is disabled."
            recordDetection(kind: event.kind, detail: "Detected only; mapping disabled")
            debugLogWriter.append("Gesture detected: \(event.kind.displayName) | mapping disabled")
            return
        }

        let dispatched = dispatcher.dispatch(configuration.action)
        let actionDescription = configuration.action.displayString
        if dispatched {
            captureMessage = "Triggered \(event.kind.displayName) → \(actionDescription)"
            recordDetection(kind: event.kind, detail: "Sent \(actionDescription)")
            debugLogWriter.append("Gesture detected: \(event.kind.displayName) | dispatched \(actionDescription)")
        } else {
            refreshAccessibilityStatus()
            captureMessage = "Gesture detected, but Accessibility access is still required to send actions."
            recordDetection(kind: event.kind, detail: "Detected only; shortcut dispatch blocked")
            debugLogWriter.append("Gesture detected: \(event.kind.displayName) | dispatch blocked")
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
        debugLogWriter.append("Frame: \(summary)")
    }

    private func logDiagnostics(_ diagnostics: CaptureDiagnosticsViewState) {
        debugLogWriter.append(
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
