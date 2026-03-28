import Foundation

public enum GestureEventPhase: Equatable, Sendable {
    case armed
    case recognized
}

public struct GestureEvent: Equatable, Sendable {
    public let kind: GestureKind
    public let timestamp: TimeInterval
    public let phase: GestureEventPhase
    public let shouldPlayHaptic: Bool

    public init(
        kind: GestureKind,
        timestamp: TimeInterval,
        phase: GestureEventPhase = .recognized,
        shouldPlayHaptic: Bool = true
    ) {
        self.kind = kind
        self.timestamp = timestamp
        self.phase = phase
        self.shouldPlayHaptic = shouldPlayHaptic
    }
}
