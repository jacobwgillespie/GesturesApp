import Carbon.HIToolbox
import Foundation

public enum GestureKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case threeFingerTap
    case threeFingerSwipeDown
    case twoFingerTipTapLeft
    case twoFingerTipTapRight
    case threeFingerTipTapLeft

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .threeFingerTap:
            "Three-Finger Tap"
        case .threeFingerSwipeDown:
            "Three-Finger Swipe Down"
        case .twoFingerTipTapLeft:
            "Two-Finger Tip-Tap Left"
        case .twoFingerTipTapRight:
            "Two-Finger Tip-Tap Right"
        case .threeFingerTipTapLeft:
            "Three-Finger Tip-Tap Left"
        }
    }

    public var detail: String {
        switch self {
        case .threeFingerTap:
            "Three fingers touch briefly with minimal movement."
        case .threeFingerSwipeDown:
            "Three fingers move downward together."
        case .twoFingerTipTapLeft:
            "One finger anchors while the second finger taps on its left side."
        case .twoFingerTipTapRight:
            "One finger anchors while the second finger taps on its right side."
        case .threeFingerTipTapLeft:
            "Two fingers anchor while a third finger taps on their left side."
        }
    }

    public var defaultShortcutBinding: ShortcutBinding {
        switch self {
        case .threeFingerTap:
            ShortcutBinding(keyCode: UInt16(kVK_Space), modifierFlags: [.command, .option])
        case .threeFingerSwipeDown:
            ShortcutBinding(keyCode: UInt16(kVK_ANSI_W), modifierFlags: [.command])
        case .twoFingerTipTapLeft:
            ShortcutBinding(keyCode: UInt16(kVK_LeftArrow), modifierFlags: [.command, .option])
        case .twoFingerTipTapRight:
            ShortcutBinding(keyCode: UInt16(kVK_RightArrow), modifierFlags: [.command, .option])
        case .threeFingerTipTapLeft:
            ShortcutBinding(keyCode: UInt16(kVK_ANSI_R), modifierFlags: [.command])
        }
    }

    public var defaultConfiguration: GestureBindingConfiguration {
        switch self {
        case .threeFingerTap:
            GestureBindingConfiguration(
                isEnabled: true,
                action: .middleClick
            )
        case .threeFingerSwipeDown:
            GestureBindingConfiguration(
                isEnabled: true,
                shortcut: defaultShortcutBinding
            )
        case .twoFingerTipTapLeft:
            GestureBindingConfiguration(
                isEnabled: true,
                shortcut: defaultShortcutBinding
            )
        case .twoFingerTipTapRight:
            GestureBindingConfiguration(
                isEnabled: true,
                shortcut: defaultShortcutBinding
            )
        case .threeFingerTipTapLeft:
            GestureBindingConfiguration(
                isEnabled: true,
                shortcut: defaultShortcutBinding
            )
        }
    }
}
