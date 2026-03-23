import AppKit
import CoreGraphics
import Foundation

public protocol ShortcutDispatching {
    @discardableResult
    func dispatch(_ action: GestureAction) -> Bool
}

public final class ShortcutDispatcher: ShortcutDispatching {
    public typealias Logger = @Sendable (String) -> Void

    private enum DispatchKey {
        static let command: CGKeyCode = 55
        static let shift: CGKeyCode = 56
        static let option: CGKeyCode = 58
        static let control: CGKeyCode = 59
    }

    private let logger: Logger?

    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    @discardableResult
    public func dispatch(_ action: GestureAction) -> Bool {
        switch action {
        case let .keyboardShortcut(binding):
            dispatchShortcut(binding)
        case .middleClick:
            dispatchMiddleClick()
        }
    }

    @discardableResult
    private func dispatchShortcut(_ binding: ShortcutBinding) -> Bool {
        logger?("Dispatch request: shortcut=\(binding.displayString) keyCode=\(binding.keyCode) modifiers=\(binding.modifierFlagsRawValue)")

        guard PermissionsManager.isAccessibilityTrusted(prompt: false) else {
            logger?("Dispatch blocked: Accessibility permission missing")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger?("Dispatch failed: could not create CGEventSource")
            return false
        }

        guard let sequence = makeEventSequence(for: binding, source: source) else {
            logger?("Dispatch failed: could not create key event sequence")
            return false
        }

        for step in sequence {
            logger?("Dispatch post: \(step.label) keyCode=\(step.keyCode) flags=\(step.flags.rawValue)")
            step.event.post(tap: .cghidEventTap)
            if step.delayAfterMicroseconds > 0 {
                usleep(step.delayAfterMicroseconds)
            }
        }
        logger?("Dispatch success: shortcut=\(binding.displayString)")
        return true
    }
}

private extension ShortcutDispatcher {
    struct EventStep {
        var label: String
        var keyCode: CGKeyCode
        var flags: CGEventFlags
        var event: CGEvent
        var delayAfterMicroseconds: useconds_t = 0
    }

    func makeEventSequence(for binding: ShortcutBinding, source: CGEventSource) -> [EventStep]? {
        let modifiers = modifierSequence(for: binding.modifierFlags)
        var steps: [EventStep] = []
        var activeFlags: CGEventFlags = []

        for modifier in modifiers {
            activeFlags.formUnion(modifier.flag)
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.keyCode, keyDown: true) else {
                return nil
            }
            event.flags = activeFlags
            steps.append(
                EventStep(
                    label: "modifierDown",
                    keyCode: modifier.keyCode,
                    flags: activeFlags,
                    event: event
                )
            )
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: binding.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: binding.keyCode, keyDown: false) else {
            return nil
        }

        keyDown.flags = activeFlags
        keyUp.flags = activeFlags
        steps.append(
            EventStep(
                label: "keyDown",
                keyCode: binding.keyCode,
                flags: activeFlags,
                event: keyDown,
                delayAfterMicroseconds: 12_000
            )
        )
        steps.append(
            EventStep(
                label: "keyUp",
                keyCode: binding.keyCode,
                flags: activeFlags,
                event: keyUp
            )
        )

        for modifier in modifiers.reversed() {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.keyCode, keyDown: false) else {
                return nil
            }
            event.flags = activeFlags
            steps.append(
                EventStep(
                    label: "modifierUp",
                    keyCode: modifier.keyCode,
                    flags: activeFlags,
                    event: event
                )
            )
            activeFlags.remove(modifier.flag)
        }

        return steps
    }

    func modifierSequence(for flags: NSEvent.ModifierFlags) -> [(keyCode: CGKeyCode, flag: CGEventFlags)] {
        var modifiers: [(keyCode: CGKeyCode, flag: CGEventFlags)] = []
        if flags.contains(.control) {
            modifiers.append((DispatchKey.control, .maskControl))
        }
        if flags.contains(.option) {
            modifiers.append((DispatchKey.option, .maskAlternate))
        }
        if flags.contains(.shift) {
            modifiers.append((DispatchKey.shift, .maskShift))
        }
        if flags.contains(.command) {
            modifiers.append((DispatchKey.command, .maskCommand))
        }
        return modifiers
    }

    @discardableResult
    func dispatchMiddleClick() -> Bool {
        logger?("Dispatch request: middleClick")

        guard PermissionsManager.isAccessibilityTrusted(prompt: false) else {
            logger?("Dispatch blocked: Accessibility permission missing")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger?("Dispatch failed: could not create CGEventSource")
            return false
        }

        let location = CGEvent(source: nil)?.location ?? .zero
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: location,
            mouseButton: .center
        ),
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseUp,
            mouseCursorPosition: location,
            mouseButton: .center
        ) else {
            logger?("Dispatch failed: could not create middle mouse events")
            return false
        }

        mouseDown.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        mouseUp.setIntegerValueField(.mouseEventButtonNumber, value: 2)

        logger?("Dispatch post: middleMouseDown location=(\(Int(location.x.rounded())), \(Int(location.y.rounded())))")
        mouseDown.post(tap: .cghidEventTap)
        usleep(12_000)
        logger?("Dispatch post: middleMouseUp location=(\(Int(location.x.rounded())), \(Int(location.y.rounded())))")
        mouseUp.post(tap: .cghidEventTap)
        logger?("Dispatch success: middleClick")
        return true
    }
}
