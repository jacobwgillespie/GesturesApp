import AppKit

public extension ShortcutBinding {
    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.init(
            keyCode: keyCode,
            modifierFlagsRawValue: modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        )
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
            .intersection([.command, .option, .control, .shift])
    }
}
