import Foundation

public struct GestureEvent: Equatable, Sendable {
    public let kind: GestureKind
    public let timestamp: TimeInterval

    public init(kind: GestureKind, timestamp: TimeInterval) {
        self.kind = kind
        self.timestamp = timestamp
    }
}
