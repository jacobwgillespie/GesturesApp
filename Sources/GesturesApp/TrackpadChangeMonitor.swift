import Foundation
import IOKit.hid

enum TrackpadHardwareChangeEvent: String {
    case connected = "connected"
    case disconnected = "disconnected"
}

final class TrackpadChangeMonitor {
    var onChange: (@Sendable (TrackpadHardwareChangeEvent) -> Void)?

    private let manager: IOHIDManager
    private var isRunning = false
    private var suppressConnectedEventsUntil: Date?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(0))
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        let matchingDictionaries: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_Digitizer,
                kIOHIDDeviceUsageKey: kHIDUsage_Dig_TouchPad,
            ],
        ]

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries as CFArray)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceMatchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceRemovalCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        suppressConnectedEventsUntil = Date().addingTimeInterval(0.75)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            return false
        }

        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isRunning = false
        suppressConnectedEventsUntil = nil
    }

    private func handleChange(_ event: TrackpadHardwareChangeEvent) {
        if event == .connected,
           let suppressConnectedEventsUntil,
           Date() < suppressConnectedEventsUntil {
            return
        }
        onChange?(event)
    }

    private static let deviceMatchingCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let monitor = Unmanaged<TrackpadChangeMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleChange(.connected)
    }

    private static let deviceRemovalCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let monitor = Unmanaged<TrackpadChangeMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleChange(.disconnected)
    }
}
