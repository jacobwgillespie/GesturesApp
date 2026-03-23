import GesturesCore
import XCTest

final class GestureRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerTap() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.70, y: 0.61),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.31, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.63),
            contact(id: 3, x: 0.69, y: 0.60),
        ])))

        let event = recognizer.process(frame: frame(time: 0.12, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerTap)
    }

    func testRecognizesThreeFingerSwipeDown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.32, y: 0.78),
            contact(id: 2, x: 0.49, y: 0.80),
            contact(id: 3, x: 0.67, y: 0.77),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.33, y: 0.63),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.68, y: 0.62),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.34, y: 0.47),
            contact(id: 2, x: 0.50, y: 0.49),
            contact(id: 3, x: 0.67, y: 0.46),
        ])))

        let event = recognizer.process(frame: frame(time: 0.28, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerSwipeDown)
    }

    func testDistinguishesTipTapLeftAndRight() {
        let leftRecognizer = GestureRecognizer()
        XCTAssertNil(leftRecognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
        ])))
        XCTAssertNil(leftRecognizer.process(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
            contact(id: 2, x: 0.46, y: 0.48),
        ])))
        let leftEvent = leftRecognizer.process(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
        ]))
        XCTAssertEqual(leftEvent?.kind, .twoFingerTipTapLeft)
        XCTAssertNil(leftRecognizer.process(frame: frame(time: 0.20, contacts: [])))

        let rightRecognizer = GestureRecognizer()
        XCTAssertNil(rightRecognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(rightRecognizer.process(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))
        let rightEvent = rightRecognizer.process(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(rightEvent?.kind, .twoFingerTipTapRight)
        XCTAssertNil(rightRecognizer.process(frame: frame(time: 0.20, contacts: [])))
    }

    func testTipTapFallsBackToSessionEndWhenBothFingersLiftTogether() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.18, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let event = recognizer.process(frame: frame(time: 0.20, contacts: []))
        XCTAssertEqual(event?.kind, .twoFingerTipTapRight)
    }

    func testTipTapCanRepeatWhileAnchorFingerStaysDown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.process(frame: frame(time: 0.30, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))

        let secondEvent = recognizer.process(frame: frame(time: 0.38, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(secondEvent?.kind, .twoFingerTipTapRight)
        XCTAssertNil(recognizer.process(frame: frame(time: 0.48, contacts: [])))
    }

    func testTipTapDebouncesRapidDuplicateEmission() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.process(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.28, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
    }

    func testTipTapCanRepeatAfterDebounceWindow() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.process(frame: frame(time: 0.30, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        let secondEvent = recognizer.process(frame: frame(time: 0.38, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(secondEvent?.kind, .twoFingerTipTapRight)
    }

    func testTipTapSuppressesRepeatWithinSameAnchorCooldown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.process(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.28, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
    }

    func testRejectsNoisyAmbiguousInput() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.70, y: 0.61),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.44, y: 0.61),
            contact(id: 2, x: 0.62, y: 0.65),
            contact(id: 3, x: 0.84, y: 0.60),
        ])))

        let event = recognizer.process(frame: frame(time: 0.14, contacts: []))
        XCTAssertNil(event)
    }

    func testRejectsWrongFingerCount() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.45, y: 0.60),
            contact(id: 2, x: 0.58, y: 0.60),
        ])))
        XCTAssertNil(recognizer.process(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.45, y: 0.60),
            contact(id: 2, x: 0.58, y: 0.60),
        ])))

        let event = recognizer.process(frame: frame(time: 0.12, contacts: []))
        XCTAssertNil(event)
    }

    private func frame(time: TimeInterval, contacts: [TouchContact]) -> TouchFrame {
        TouchFrame(timestamp: time, contacts: contacts)
    }

    private func contact(id: Int, x: Double, y: Double, phase: TouchPhase = .touching) -> TouchContact {
        TouchContact(
            identifier: id,
            position: TouchPoint(x: x, y: y),
            velocity: TouchPoint(x: 0, y: 0),
            pressure: 1,
            phase: phase
        )
    }
}
