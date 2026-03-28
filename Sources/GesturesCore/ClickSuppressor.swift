import CoreGraphics
import Foundation

/// Installs a CGEventTap that swallows left-click events for a brief window
/// after a gesture fires, preventing the touch from also being interpreted
/// as a macOS tap-to-click.
public final class ClickSuppressor: @unchecked Sendable {
    public typealias Logger = @Sendable (String) -> Void

    private let lock = NSLock()
    private let logger: Logger?
    private var suppressUntil: TimeInterval = 0
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Duration (in seconds) to suppress clicks after `suppress()` is called.
    private static let suppressionDuration: TimeInterval = 0.2

    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    deinit { stop() }

    /// Install the event tap on the main run loop. Returns `true` on success.
    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: clickSuppressorCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger?("ClickSuppressor: failed to create event tap")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger?("ClickSuppressor: event tap installed")
        return true
    }

    /// Begin suppressing left-click events. Safe to call from any thread.
    public func suppress() {
        lock.lock()
        suppressUntil = ProcessInfo.processInfo.systemUptime + Self.suppressionDuration
        lock.unlock()
        logger?("ClickSuppressor: suppressing clicks for \(Self.suppressionDuration)s")
    }

    /// Remove the event tap.
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func shouldSuppress() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ProcessInfo.processInfo.systemUptime < suppressUntil
    }

    fileprivate func reenableIfNeeded() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        logger?("ClickSuppressor: re-enabled event tap after timeout")
    }
}

private func clickSuppressorCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let suppressor = Unmanaged<ClickSuppressor>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        suppressor.reenableIfNeeded()
        return Unmanaged.passUnretained(event)
    }

    if suppressor.shouldSuppress() {
        return nil
    }

    return Unmanaged.passUnretained(event)
}
