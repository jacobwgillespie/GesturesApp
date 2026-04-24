import Foundation
import IOKit.hid

enum TrackpadHardwareChangeKind: String, Sendable {
    case connected = "connected"
    case disconnected = "disconnected"
}

struct TrackpadHardwareChangeEvent: Sendable {
    let kind: TrackpadHardwareChangeKind
}

struct TrackpadHardwareSnapshot: Equatable, Sendable {
    let devices: [TrackpadHardwareDevice]

    init(devices: [TrackpadHardwareDevice] = []) {
        self.devices = devices.sorted()
    }

    var count: Int {
        devices.count
    }
}

struct TrackpadHardwareDevice: Equatable, Comparable, Sendable {
    let registryID: UInt64
    let transport: String

    static func < (lhs: TrackpadHardwareDevice, rhs: TrackpadHardwareDevice) -> Bool {
        if lhs.registryID != rhs.registryID {
            return lhs.registryID < rhs.registryID
        }
        return lhs.transport < rhs.transport
    }
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

    func snapshot() -> TrackpadHardwareSnapshot {
        let devices = copyDevices().compactMap(Self.describe)
        return TrackpadHardwareSnapshot(devices: devices)
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

    private func handleChange(_ kind: TrackpadHardwareChangeKind) {
        if kind == .connected,
           let suppressConnectedEventsUntil,
           Date() < suppressConnectedEventsUntil {
            return
        }
        onChange?(TrackpadHardwareChangeEvent(kind: kind))
    }

    private func copyDevices() -> [IOHIDDevice] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            return []
        }

        return (deviceSet as NSSet).map { $0 as! IOHIDDevice }
    }

    private static func describe(_ device: IOHIDDevice) -> TrackpadHardwareDevice? {
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else {
            return nil
        }

        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
        return TrackpadHardwareDevice(
            registryID: registryID,
            transport: transport ?? "unknown"
        )
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
