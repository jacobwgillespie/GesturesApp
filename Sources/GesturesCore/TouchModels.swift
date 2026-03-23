import Foundation

public struct TouchPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func distance(to other: TouchPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

public enum TouchPhase: Int32, Codable, Sendable {
    case notTracking = 0
    case startInRange = 1
    case hoverInRange = 2
    case makeTouch = 3
    case touching = 4
    case breakTouch = 5
    case lingerInRange = 6
    case outOfRange = 7

    public var isActiveSurfaceContact: Bool {
        switch self {
        case .makeTouch, .touching, .breakTouch:
            true
        default:
            false
        }
    }
}

public struct TouchContact: Equatable, Hashable, Sendable {
    public var identifier: Int
    public var position: TouchPoint
    public var velocity: TouchPoint
    public var pressure: Double
    public var phase: TouchPhase

    public init(identifier: Int, position: TouchPoint, velocity: TouchPoint, pressure: Double, phase: TouchPhase) {
        self.identifier = identifier
        self.position = position
        self.velocity = velocity
        self.pressure = pressure
        self.phase = phase
    }
}

public struct TouchFrame: Equatable, Sendable {
    public var timestamp: TimeInterval
    public var contacts: [TouchContact]

    public init(timestamp: TimeInterval, contacts: [TouchContact]) {
        self.timestamp = timestamp
        self.contacts = contacts
    }
}

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTRawTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var stage: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var total: Float
    var pressure: Float
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var unknown14: Int32
    var unknown15: Int32
    var density: Float
}

extension TouchContact {
    init?(rawTouch: MTRawTouch) {
        guard let phase = TouchPhase(rawValue: rawTouch.stage) else {
            return nil
        }

        self.init(
            identifier: Int(rawTouch.identifier),
            position: TouchPoint(
                x: Double(rawTouch.normalizedVector.position.x),
                y: Double(rawTouch.normalizedVector.position.y)
            ),
            velocity: TouchPoint(
                x: Double(rawTouch.normalizedVector.velocity.x),
                y: Double(rawTouch.normalizedVector.velocity.y)
            ),
            pressure: Double(rawTouch.pressure),
            phase: phase
        )
    }
}
