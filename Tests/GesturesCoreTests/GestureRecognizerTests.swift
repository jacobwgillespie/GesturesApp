import GesturesCore
import XCTest

private extension GestureRecognizer {
    /// Test helper that returns just the event from process().
    func processEvent(frame: TouchFrame) -> GestureEvent? {
        process(frame: frame).event
    }
}

final class GestureRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerTap() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.70, y: 0.61),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.31, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.63),
            contact(id: 3, x: 0.69, y: 0.60),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.12, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerTap)
    }

    func testRecognizesThreeFingerTapOnBreakTouchFrame() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.70, y: 0.61),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.31, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.63),
            contact(id: 3, x: 0.69, y: 0.60),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.31, y: 0.62, phase: .breakTouch),
            contact(id: 2, x: 0.50, y: 0.63, phase: .breakTouch),
            contact(id: 3, x: 0.69, y: 0.60, phase: .breakTouch),
        ]))
        XCTAssertEqual(event?.kind, .threeFingerTap)
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.16, contacts: [])))
    }

    func testRecognizesThreeFingerSwipeDown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.32, y: 0.78),
            contact(id: 2, x: 0.49, y: 0.80),
            contact(id: 3, x: 0.67, y: 0.77),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.33, y: 0.63),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.68, y: 0.62),
        ])))
        let armedEvent = recognizer.processEvent(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.34, y: 0.47),
            contact(id: 2, x: 0.50, y: 0.49),
            contact(id: 3, x: 0.67, y: 0.46),
        ]))
        XCTAssertEqual(armedEvent?.kind, .threeFingerSwipeDown)
        XCTAssertEqual(armedEvent?.phase, .armed)
        XCTAssertTrue(armedEvent?.shouldPlayHaptic == true)

        let event = recognizer.processEvent(frame: frame(time: 0.28, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerSwipeDown)
        XCTAssertEqual(event?.phase, .recognized)
        XCTAssertFalse(event?.shouldPlayHaptic == true)
    }

    func testRecognizesThreeFingerSwipeDownOnBreakTouchFrame() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.32, y: 0.78),
            contact(id: 2, x: 0.49, y: 0.80),
            contact(id: 3, x: 0.67, y: 0.77),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.33, y: 0.63),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.68, y: 0.62),
        ])))

        let armedEvent = recognizer.processEvent(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.34, y: 0.47, phase: .breakTouch),
            contact(id: 2, x: 0.50, y: 0.49, phase: .breakTouch),
            contact(id: 3, x: 0.67, y: 0.46, phase: .breakTouch),
        ]))
        XCTAssertEqual(armedEvent?.kind, .threeFingerSwipeDown)
        XCTAssertEqual(armedEvent?.phase, .armed)
        XCTAssertTrue(armedEvent?.shouldPlayHaptic == true)

        let event = recognizer.processEvent(frame: frame(time: 0.28, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerSwipeDown)
        XCTAssertEqual(event?.phase, .recognized)
        XCTAssertFalse(event?.shouldPlayHaptic == true)
    }

    func testThreeFingerSwipeDownArmsOnlyOnceBeforeRecognition() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.32, y: 0.78),
            contact(id: 2, x: 0.49, y: 0.80),
            contact(id: 3, x: 0.67, y: 0.77),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.33, y: 0.63),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.68, y: 0.62),
        ])))

        let firstArmedEvent = recognizer.processEvent(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.34, y: 0.47),
            contact(id: 2, x: 0.50, y: 0.49),
            contact(id: 3, x: 0.67, y: 0.46),
        ]))
        XCTAssertEqual(firstArmedEvent?.phase, .armed)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.30, contacts: [
            contact(id: 1, x: 0.35, y: 0.40),
            contact(id: 2, x: 0.50, y: 0.42),
            contact(id: 3, x: 0.67, y: 0.39),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.36, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerSwipeDown)
        XCTAssertEqual(event?.phase, .recognized)
    }

    func testDistinguishesTipTapLeftAndRight() {
        let leftRecognizer = GestureRecognizer()
        XCTAssertNil(leftRecognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
        ])))
        XCTAssertNil(leftRecognizer.processEvent(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
            contact(id: 2, x: 0.46, y: 0.48),
        ])))
        let leftEvent = leftRecognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.60, y: 0.48),
        ]))
        XCTAssertEqual(leftEvent?.kind, .twoFingerTipTapLeft)
        XCTAssertNil(leftRecognizer.processEvent(frame: frame(time: 0.20, contacts: [])))

        let rightRecognizer = GestureRecognizer()
        XCTAssertNil(rightRecognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(rightRecognizer.processEvent(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))
        let rightEvent = rightRecognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(rightEvent?.kind, .twoFingerTipTapRight)
        XCTAssertNil(rightRecognizer.processEvent(frame: frame(time: 0.20, contacts: [])))
    }

    func testTipTapFallsBackToSessionEndWhenBothFingersLiftTogether() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.18, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.20, contacts: []))
        XCTAssertEqual(event?.kind, .twoFingerTipTapRight)
    }

    func testTipTapCanRepeatWhileAnchorFingerStaysDown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.30, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))

        let secondEvent = recognizer.processEvent(frame: frame(time: 0.38, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(secondEvent?.kind, .twoFingerTipTapRight)
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.48, contacts: [])))
    }

    func testTipTapDoesNotRetriggerWhenAnchorFingerLifts() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let tipTapEvent = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(tipTapEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.40, y: 0.48, phase: .breakTouch),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.24, contacts: [])))
    }

    func testTipTapDebouncesRapidDuplicateEmission() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.28, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
    }

    func testTipTapCanRepeatAfterDebounceWindow() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.30, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        let secondEvent = recognizer.processEvent(frame: frame(time: 0.38, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(secondEvent?.kind, .twoFingerTipTapRight)
    }

    func testRejectsTipTapWhenTouchesAreTooFarApart() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.10, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.10, y: 0.48),
            contact(id: 2, x: 0.62, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.10, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.22, contacts: [])))
    }

    func testRejectsFallbackTipTapWhenTouchesAreTooFarApart() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.15, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.15, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.15, y: 0.48),
            contact(id: 2, x: 0.70, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.18, contacts: [
            contact(id: 1, x: 0.15, y: 0.48),
            contact(id: 2, x: 0.70, y: 0.48),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.20, contacts: []))
        XCTAssertNil(event)
    }

    func testTipTapSuppressesRepeatWithinSameAnchorCooldown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ])))

        let firstEvent = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .twoFingerTipTapRight)

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 3, x: 0.55, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.28, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ])))
    }

    func testRecognizesThreeFingerTipTapLeft() {
        let recognizer = GestureRecognizer()

        // Two anchors land
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.04, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ])))

        // Tip taps to the left
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 3, x: 0.35, y: 0.48),
        ])))

        // Tip lifts, anchors remain
        let event = recognizer.processEvent(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ]))
        XCTAssertEqual(event?.kind, .threeFingerTipTapLeft)

        // No duplicate on session end
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.22, contacts: [])))
    }

    func testThreeFingerTipTapLeftFallbackWhenAllFingersLift() {
        let recognizer = GestureRecognizer()

        // Anchors held long enough to exceed tap duration threshold
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.20, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 3, x: 0.35, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 3, x: 0.35, y: 0.48),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.28, contacts: []))
        XCTAssertEqual(event?.kind, .threeFingerTipTapLeft)
    }

    func testRejectsThreeFingerTipTapWhenTipIsOnRight() {
        let recognizer = GestureRecognizer()

        // Anchors held long enough to exceed tap duration threshold
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.48),
            contact(id: 2, x: 0.45, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.10, contacts: [
            contact(id: 1, x: 0.30, y: 0.48),
            contact(id: 2, x: 0.45, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.18, contacts: [
            contact(id: 1, x: 0.30, y: 0.48),
            contact(id: 2, x: 0.45, y: 0.48),
            contact(id: 3, x: 0.60, y: 0.48),
        ])))

        // Tip lifts — should NOT be threeFingerTipTapLeft since tip is to the right
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.24, contacts: [
            contact(id: 1, x: 0.30, y: 0.48),
            contact(id: 2, x: 0.45, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.32, contacts: [])))
    }

    func testThreeFingerTipTapLeftCanRepeatWhileAnchorsStayDown() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 3, x: 0.35, y: 0.48),
        ])))

        let firstEvent = recognizer.processEvent(frame: frame(time: 0.12, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ]))
        XCTAssertEqual(firstEvent?.kind, .threeFingerTipTapLeft)

        // Second tap after cooldown
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.28, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 4, x: 0.35, y: 0.48),
        ])))

        let secondEvent = recognizer.processEvent(frame: frame(time: 0.36, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ]))
        XCTAssertEqual(secondEvent?.kind, .threeFingerTipTapLeft)
    }

    func testTipTapSuppressesClicksWhenCandidateForms() {
        let recognizer = GestureRecognizer()

        // Anchor finger down — no suppression yet
        var result = recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertFalse(result.suppressClicks)

        // Tip finger joins — candidate forms, suppression should start
        result = recognizer.process(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ]))
        XCTAssertTrue(result.suppressClicks)
        XCTAssertNil(result.event)

        // Both fingers still down — candidate still active, suppress continues
        result = recognizer.process(frame: frame(time: 0.10, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
            contact(id: 2, x: 0.55, y: 0.48),
        ]))
        XCTAssertTrue(result.suppressClicks)

        // Tip lifts — gesture recognized, still suppressing
        result = recognizer.process(frame: frame(time: 0.14, contacts: [
            contact(id: 1, x: 0.40, y: 0.48),
        ]))
        XCTAssertEqual(result.event?.kind, .twoFingerTipTapRight)
        XCTAssertTrue(result.suppressClicks)
    }

    func testThreeFingerTipTapSuppressesClicksWhenCandidateForms() {
        let recognizer = GestureRecognizer()

        // Two anchors down — no suppression
        var result = recognizer.process(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
        ]))
        XCTAssertFalse(result.suppressClicks)

        // Tip joins — candidate forms, suppression starts
        result = recognizer.process(frame: frame(time: 0.06, contacts: [
            contact(id: 1, x: 0.50, y: 0.48),
            contact(id: 2, x: 0.65, y: 0.48),
            contact(id: 3, x: 0.35, y: 0.48),
        ]))
        XCTAssertTrue(result.suppressClicks)
        XCTAssertNil(result.event)
    }

    func testRejectsNoisyAmbiguousInput() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.30, y: 0.62),
            contact(id: 2, x: 0.50, y: 0.64),
            contact(id: 3, x: 0.70, y: 0.61),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.44, y: 0.61),
            contact(id: 2, x: 0.62, y: 0.65),
            contact(id: 3, x: 0.84, y: 0.60),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.14, contacts: []))
        XCTAssertNil(event)
    }

    func testRejectsWrongFingerCount() {
        let recognizer = GestureRecognizer()

        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.00, contacts: [
            contact(id: 1, x: 0.45, y: 0.60),
            contact(id: 2, x: 0.58, y: 0.60),
        ])))
        XCTAssertNil(recognizer.processEvent(frame: frame(time: 0.08, contacts: [
            contact(id: 1, x: 0.45, y: 0.60),
            contact(id: 2, x: 0.58, y: 0.60),
        ])))

        let event = recognizer.processEvent(frame: frame(time: 0.12, contacts: []))
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
