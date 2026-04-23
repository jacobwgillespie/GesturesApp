import Foundation

public struct CaptureDiagnostics: Sendable {
    public var frameworkLoaded: Bool
    public var enumeratedDeviceCount: Int
    public var startedDeviceCount: Int
    public var successfulRegistrationCount: Int
    public var callbackCount: Int
    public var lastCallbackAt: Date?
    public var statusSummary: String

    public init(
        frameworkLoaded: Bool = false,
        enumeratedDeviceCount: Int = 0,
        startedDeviceCount: Int = 0,
        successfulRegistrationCount: Int = 0,
        callbackCount: Int = 0,
        lastCallbackAt: Date? = nil,
        statusSummary: String = "Capture has not started."
    ) {
        self.frameworkLoaded = frameworkLoaded
        self.enumeratedDeviceCount = enumeratedDeviceCount
        self.startedDeviceCount = startedDeviceCount
        self.successfulRegistrationCount = successfulRegistrationCount
        self.callbackCount = callbackCount
        self.lastCallbackAt = lastCallbackAt
        self.statusSummary = statusSummary
    }
}

public struct AvailableTrackpadSnapshot: Equatable, Sendable {
    public let identifiers: [UInt]
    public let isUsingDefaultDeviceFallback: Bool

    public init(identifiers: [UInt] = [], isUsingDefaultDeviceFallback: Bool = false) {
        self.identifiers = identifiers.sorted()
        self.isUsingDefaultDeviceFallback = isUsingDefaultDeviceFallback
    }

    public var count: Int {
        identifiers.isEmpty && isUsingDefaultDeviceFallback ? 1 : identifiers.count
    }
}

public final class MultitouchService: @unchecked Sendable {
    public var onGesture: (@Sendable (GestureEvent) -> Void)?
    public var onFrame: (@Sendable (TouchFrame) -> Void)?
    public var onDiagnostics: (@Sendable (CaptureDiagnostics) -> Void)?
    public var clickSuppressor: ClickSuppressor?

    public private(set) var lastErrorMessage: String?
    public private(set) var isRunning = false

    private let stateLock = NSLock()
    private let frameworkLock = NSLock()
    private let recognizerLock = NSLock()
    private let recognizer = GestureRecognizer()
    private let framework: MultitouchFramework?
    private var session: MultitouchCaptureSession?
    private var lastPublishedFrameSignature: String?
    private var diagnostics = CaptureDiagnostics()

    public init() {
        framework = MultitouchFramework()
        diagnostics.frameworkLoaded = framework != nil
        diagnostics.statusSummary = framework == nil
            ? "Multitouch framework failed to load."
            : "Framework loaded."
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        let startState = stateLock.withLock { () -> (alreadyRunning: Bool, framework: MultitouchFramework?) in
            (isRunning, framework)
        }

        if startState.alreadyRunning {
            return true
        }

        guard let framework = startState.framework else {
            let result = stateLock.withLock { () -> (Bool, Bool) in
                lastErrorMessage = "The private MultitouchSupport framework could not be loaded."
                diagnostics = CaptureDiagnostics(
                    frameworkLoaded: false,
                    statusSummary: lastErrorMessage ?? "Multitouch framework failed to load."
                )
                return (false, true)
            }

            publishDiagnostics()
            return result.0
        }

        recognizerLock.withLock {
            recognizer.reset()
        }

        MultitouchCallbackBridge.shared.install(self)
        let sessionStart = frameworkLock.withLock {
            MultitouchCaptureSession.start(
                using: framework,
                callback: MultitouchCallbackBridge.callback
            )
        }

        let result = stateLock.withLock { () -> (Bool, Bool) in
            guard !isRunning else { return (true, false) }

            guard let session = sessionStart.session else {
                lastErrorMessage = "No multitouch trackpad device was found."
                diagnostics = CaptureDiagnostics(
                    frameworkLoaded: true,
                    enumeratedDeviceCount: sessionStart.enumeratedDeviceCount,
                    startedDeviceCount: 0,
                    successfulRegistrationCount: sessionStart.successfulRegistrationCount,
                    statusSummary: lastErrorMessage ?? "No multitouch device was found."
                )
                return (false, true)
            }

            self.session = session
            lastPublishedFrameSignature = nil
            lastErrorMessage = nil
            isRunning = true
            diagnostics = CaptureDiagnostics(
                frameworkLoaded: true,
                enumeratedDeviceCount: session.enumeratedDeviceCount,
                startedDeviceCount: session.devices.count,
                successfulRegistrationCount: session.successfulRegistrationCount,
                callbackCount: 0,
                lastCallbackAt: nil,
                statusSummary: "Started \(session.devices.count) device(s); waiting for touch callbacks."
            )
            return (true, true)
        }

        if !result.0 {
            MultitouchCallbackBridge.shared.clear(self)
        }

        if result.1 {
            publishDiagnostics()
        }
        return result.0
    }

    public func stop() {
        let stopState = stateLock.withLock { () -> (MultitouchFramework?, MultitouchCaptureSession?, Bool) in
            guard isRunning else { return (nil, nil, false) }
            let framework = self.framework
            let session = self.session
            self.session = nil
            MultitouchCallbackBridge.shared.clear(self)
            lastPublishedFrameSignature = nil
            isRunning = false
            recognizerLock.withLock {
                recognizer.reset()
            }
            diagnostics.statusSummary = "Capture stopped."
            return (framework, session, true)
        }

        if stopState.2, let framework = stopState.0, let session = stopState.1 {
            frameworkLock.withLock {
                session.stop(using: framework, callback: MultitouchCallbackBridge.callback)
            }
        }

        if stopState.2 {
            publishDiagnostics()
        }
    }

    public func availableTrackpadSnapshot() -> AvailableTrackpadSnapshot {
        frameworkLock.withLock {
            guard let framework else { return AvailableTrackpadSnapshot() }

            let enumeratedDevices = framework.deviceList()
            var uniqueDeviceIdentifiers = Set<UInt>()
            for device in enumeratedDevices {
                guard uniqueDeviceIdentifiers.insert(UInt(bitPattern: device)).inserted else {
                    continue
                }
                framework.release(device: device)
            }

            let uniqueEnumeratedDevices = uniqueDeviceIdentifiers.sorted()
            if !uniqueEnumeratedDevices.isEmpty {
                return AvailableTrackpadSnapshot(identifiers: uniqueEnumeratedDevices)
            }

            guard let defaultDevice = framework.createDefaultDevice() else {
                return AvailableTrackpadSnapshot()
            }
            framework.release(device: defaultDevice)
            return AvailableTrackpadSnapshot(isUsingDefaultDeviceFallback: true)
        }
    }

    fileprivate func handleCallback(touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double) {
        let rawTouches: [MTRawTouch]
        if let touches, count > 0 {
            let typedTouches = touches.bindMemory(to: MTRawTouch.self, capacity: Int(count))
            rawTouches = Array(UnsafeBufferPointer(start: typedTouches, count: Int(count)))
        } else {
            rawTouches = []
        }

        let contacts = rawTouches.compactMap(TouchContact.init(rawTouch:))
        let frame = TouchFrame(timestamp: timestamp, contacts: contacts)
        let (diagnosticsShouldPublish, frameHandler, shouldPublishFrame) = stateLock.withLock {
            diagnostics.callbackCount += 1
            diagnostics.lastCallbackAt = Date()
            let publishDiag: Bool
            if diagnostics.callbackCount == 1 {
                diagnostics.statusSummary = "Receiving touch callbacks."
                publishDiag = true
            } else {
                publishDiag = diagnostics.callbackCount.isMultiple(of: 100)
            }
            let handler = onFrame
            let signature = frame.debugSignature
            let publishFrame = signature != lastPublishedFrameSignature
            lastPublishedFrameSignature = signature
            return (publishDiag, handler, publishFrame)
        }
        if diagnosticsShouldPublish {
            publishDiagnostics()
        }
        if shouldPublishFrame {
            DispatchQueue.main.async {
                frameHandler?(frame)
            }
        }

        let result = recognizerLock.withLock { recognizer.process(frame: frame) }
        if result.suppressClicks {
            let suppressor = stateLock.withLock { clickSuppressor }
            suppressor?.suppress()
        }
        if let event = result.event {
            let handler = stateLock.withLock { onGesture }
            DispatchQueue.main.async {
                handler?(event)
            }
        }
    }
}

private protocol MultitouchCallbackHandling: AnyObject {
    func handleCallback(touches: UnsafeMutableRawPointer?, count: Int32, timestamp: Double)
}

extension MultitouchService: MultitouchCallbackHandling {}

private extension MultitouchService {
    func publishDiagnostics() {
        let handler = stateLock.withLock { onDiagnostics }
        let snapshot = stateLock.withLock { diagnostics }
        DispatchQueue.main.async {
            handler?(snapshot)
        }
    }
}

private extension TouchFrame {
    var debugSignature: String {
        if contacts.isEmpty {
            return "0"
        }

        return contacts
            .sorted { $0.identifier < $1.identifier }
            .map { contact in
                let x = Int((contact.position.x * 100).rounded())
                let y = Int((contact.position.y * 100).rounded())
                return "\(contact.identifier):\(contact.phase.rawValue):\(x):\(y)"
            }
            .joined(separator: "|")
    }
}

private final class MultitouchCallbackBridge: @unchecked Sendable {
    static let shared = MultitouchCallbackBridge()

    static let callback: MTContactFrameCallback = { _, touches, count, timestamp, _ in
        shared.handler?.handleCallback(touches: touches, count: count, timestamp: timestamp)
    }

    private let lock = NSLock()
    private weak var activeHandler: MultitouchCallbackHandling?

    var handler: MultitouchCallbackHandling? {
        lock.withLock { activeHandler }
    }

    func install(_ handler: MultitouchCallbackHandling) {
        lock.withLock {
            activeHandler = handler
        }
    }

    func clear(_ handler: MultitouchCallbackHandling) {
        lock.withLock {
            guard activeHandler === handler else { return }
            activeHandler = nil
        }
    }
}

private struct MultitouchCaptureSession {
    let devices: [MTDeviceRef]
    let enumeratedDeviceCount: Int
    let successfulRegistrationCount: Int

    static func start(
        using framework: MultitouchFramework,
        callback: MTContactFrameCallback
    ) -> (session: MultitouchCaptureSession?, enumeratedDeviceCount: Int, successfulRegistrationCount: Int) {
        var uniquePointers = Set<UInt>()
        var startedDevices: [MTDeviceRef] = []
        var registrationAttempts = 0
        let enumeratedDevices = framework.deviceList()

        for device in enumeratedDevices {
            let key = UInt(bitPattern: device)
            guard uniquePointers.insert(key).inserted else { continue }
            framework.register(device: device, callback: callback)
            registrationAttempts += 1
            framework.start(device: device)
            startedDevices.append(device)
        }

        if startedDevices.isEmpty, let defaultDevice = framework.createDefaultDevice() {
            let key = UInt(bitPattern: defaultDevice)
            if uniquePointers.insert(key).inserted {
                framework.register(device: defaultDevice, callback: callback)
                registrationAttempts += 1
                framework.start(device: defaultDevice)
                startedDevices.append(defaultDevice)
            }
        }

        guard !startedDevices.isEmpty else {
            return (nil, enumeratedDevices.count, registrationAttempts)
        }

        return (
            MultitouchCaptureSession(
                devices: startedDevices,
                enumeratedDeviceCount: enumeratedDevices.count,
                successfulRegistrationCount: registrationAttempts
            ),
            enumeratedDevices.count,
            registrationAttempts
        )
    }

    func stop(using framework: MultitouchFramework, callback: MTContactFrameCallback) {
        for device in devices {
            framework.unregister(device: device, callback: callback)
            framework.stop(device: device)
            framework.release(device: device)
        }
    }
}
