import AppKit
import CoreGraphics
import Foundation

public struct ShortcutBinding: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifierFlagsRawValue: UInt

    public init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlagsRawValue = modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
    }

    public var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
            .intersection([.command, .option, .control, .shift])
    }

    public var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }

    public var displayString: String {
        let modifiers = [
            modifierFlags.contains(.control) ? "⌃" : "",
            modifierFlags.contains(.option) ? "⌥" : "",
            modifierFlags.contains(.shift) ? "⇧" : "",
            modifierFlags.contains(.command) ? "⌘" : "",
        ].joined()

        return modifiers + ShortcutKeyNameResolver.name(for: keyCode)
    }
}

public enum GestureActionKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case keyboardShortcut
    case middleClick

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .keyboardShortcut:
            "Keyboard Shortcut"
        case .middleClick:
            "Middle Click"
        }
    }
}

public enum GestureAction: Codable, Hashable, Sendable {
    case keyboardShortcut(ShortcutBinding)
    case middleClick

    public var kind: GestureActionKind {
        switch self {
        case .keyboardShortcut:
            .keyboardShortcut
        case .middleClick:
            .middleClick
        }
    }

    public var shortcut: ShortcutBinding? {
        guard case let .keyboardShortcut(shortcut) = self else {
            return nil
        }
        return shortcut
    }

    public var displayString: String {
        switch self {
        case let .keyboardShortcut(shortcut):
            shortcut.displayString
        case .middleClick:
            "Middle Click"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case shortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(GestureActionKind.self, forKey: .kind)
        switch kind {
        case .keyboardShortcut:
            self = .keyboardShortcut(try container.decode(ShortcutBinding.self, forKey: .shortcut))
        case .middleClick:
            self = .middleClick
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        if case let .keyboardShortcut(shortcut) = self {
            try container.encode(shortcut, forKey: .shortcut)
        }
    }
}

public struct GestureBindingConfiguration: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var action: GestureAction

    public init(isEnabled: Bool, action: GestureAction) {
        self.isEnabled = isEnabled
        self.action = action
    }

    public init(isEnabled: Bool, shortcut: ShortcutBinding) {
        self.isEnabled = isEnabled
        action = .keyboardShortcut(shortcut)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case action
        case shortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        if let action = try container.decodeIfPresent(GestureAction.self, forKey: .action) {
            self.action = action
        } else {
            let shortcut = try container.decode(ShortcutBinding.self, forKey: .shortcut)
            action = .keyboardShortcut(shortcut)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(action, forKey: .action)
    }
}

enum ShortcutKeyNameResolver {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc", 55: "Cmd", 56: "Shift",
        57: "Caps", 58: "Option", 59: "Ctrl", 60: "Right Shift",
        61: "Right Option", 62: "Right Ctrl", 63: "Fn", 64: "F17", 65: ".",
        67: "*", 69: "+", 71: "Clear", 72: "Volume Up", 73: "Volume Down",
        74: "Mute", 75: "/", 76: "Enter", 78: "-", 79: "F18", 80: "F19",
        81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
        88: "6", 89: "7", 90: "F20", 91: "8", 92: "9", 96: "F5",
        97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete",
        118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
        123: "Left", 124: "Right", 125: "Down", 126: "Up",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
