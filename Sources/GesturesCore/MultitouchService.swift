import Foundation

private let multitouchCallbackLock = NSLock()
nonisolated(unsafe) private var activeMultitouchService: MultitouchService?

private let multitouchContactCallback: MTContactFrameCallback = { _, touches, count, timestamp, _ in
    multitouchCallbackLock.withLock {
        activeMultitouchService
    }?.handleCallback(touches: touches, count: count, timestamp: timestamp)
}

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

public final class MultitouchService: @unchecked Sendable {
    public var onGesture: (@Sendable (GestureEvent) -> Void)?
    public var onFrame: (@Sendable (TouchFrame) -> Void)?
    public var onDiagnostics: (@Sendable (CaptureDiagnostics) -> Void)?

    public private(set) var lastErrorMessage: String?
    public private(set) var isRunning = false

    private let stateLock = NSLock()
    private let recognizerLock = NSLock()
    private let recognizer = GestureRecognizer()
    private let framework: MultitouchFramework?
    private var devices: [MTDeviceRef] = []
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
        let result = stateLock.withLock { () -> (Bool, Bool) in
            guard !isRunning else { return (true, false) }
            recognizerLock.withLock {
                recognizer.reset()
            }

            guard let framework else {
                lastErrorMessage = "The private MultitouchSupport framework could not be loaded."
                diagnostics = CaptureDiagnostics(
                    frameworkLoaded: false,
                    statusSummary: lastErrorMessage ?? "Multitouch framework failed to load."
                )
                return (false, true)
            }

            multitouchCallbackLock.withLock {
                activeMultitouchService = self
            }

            var uniquePointers = Set<UInt>()
            var startedDevices: [MTDeviceRef] = []
            var registrationAttempts = 0
            let enumeratedDevices = framework.deviceList()

            for device in enumeratedDevices {
                let key = UInt(bitPattern: device)
                guard uniquePointers.insert(key).inserted else { continue }
                framework.register(device: device, callback: multitouchContactCallback)
                registrationAttempts += 1
                framework.start(device: device)
                startedDevices.append(device)
            }

            if startedDevices.isEmpty, let defaultDevice = framework.createDefaultDevice() {
                let key = UInt(bitPattern: defaultDevice)
                if uniquePointers.insert(key).inserted {
                    framework.register(device: defaultDevice, callback: multitouchContactCallback)
                    registrationAttempts += 1
                    framework.start(device: defaultDevice)
                    startedDevices.append(defaultDevice)
                }
            }

            guard !startedDevices.isEmpty else {
                lastErrorMessage = "No multitouch trackpad device was found."
                diagnostics = CaptureDiagnostics(
                    frameworkLoaded: true,
                    enumeratedDeviceCount: enumeratedDevices.count,
                    startedDeviceCount: 0,
                    successfulRegistrationCount: registrationAttempts,
                    statusSummary: lastErrorMessage ?? "No multitouch device was found."
                )
                multitouchCallbackLock.withLock {
                    if activeMultitouchService === self {
                        activeMultitouchService = nil
                    }
                }
                return (false, true)
            }

            devices = startedDevices
            lastPublishedFrameSignature = nil
            lastErrorMessage = nil
            isRunning = true
            diagnostics = CaptureDiagnostics(
                frameworkLoaded: true,
                enumeratedDeviceCount: enumeratedDevices.count,
                startedDeviceCount: startedDevices.count,
                successfulRegistrationCount: registrationAttempts,
                callbackCount: 0,
                lastCallbackAt: nil,
                statusSummary: "Started \(startedDevices.count) device(s); waiting for touch callbacks."
            )
            return (true, true)
        }

        if result.1 {
            publishDiagnostics()
        }
        return result.0
    }

    public func stop() {
        let shouldPublish = stateLock.withLock { () -> Bool in
            guard isRunning else { return false }
            guard let framework else { return false }

            multitouchCallbackLock.withLock {
                if activeMultitouchService === self {
                    activeMultitouchService = nil
                }
            }

            for device in devices {
                framework.unregister(device: device, callback: multitouchContactCallback)
                framework.stop(device: device)
                framework.release(device: device)
            }

            devices.removeAll()
            lastPublishedFrameSignature = nil
            isRunning = false
            recognizerLock.withLock {
                recognizer.reset()
            }
            diagnostics.statusSummary = "Capture stopped."
            return true
        }

        if shouldPublish {
            publishDiagnostics()
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
        let diagnosticsShouldPublish = stateLock.withLock {
            diagnostics.callbackCount += 1
            diagnostics.lastCallbackAt = Date()
            if diagnostics.callbackCount == 1 {
                diagnostics.statusSummary = "Receiving touch callbacks."
                return true
            }
            return diagnostics.callbackCount.isMultiple(of: 100)
        }
        let frameHandler = stateLock.withLock { onFrame }
        let shouldPublishFrame = stateLock.withLock {
            let signature = frame.debugSignature
            defer { lastPublishedFrameSignature = signature }
            return signature != lastPublishedFrameSignature
        }
        if diagnosticsShouldPublish {
            publishDiagnostics()
        }
        if shouldPublishFrame {
            DispatchQueue.main.async {
                frameHandler?(frame)
            }
        }

        if let event = recognizerLock.withLock({ recognizer.process(frame: frame) }) {
            let handler = stateLock.withLock { onGesture }
            DispatchQueue.main.async {
                handler?(event)
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}

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
