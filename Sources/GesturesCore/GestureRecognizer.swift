import Foundation

public struct RecognizerResult {
    public var event: GestureEvent?
    public var suppressClicks: Bool
}

public final class GestureRecognizer {
    fileprivate enum Thresholds {
        static let tapDuration = 0.22
        static let tapMaxTravel = 0.075
        static let tapCentroidTravel = 0.065
        static let swipeDuration = 0.9
        static let swipeMinVerticalTravel = 0.18
        static let swipeMaxHorizontalTravel = 0.12
        static let anchorLeadTime = 0.04
        static let anchorMinDuration = 0.12
        static let tipMaxDuration = 0.18
        static let tipMaxTravel = 0.06
        static let anchorMaxTravel = 0.05
        static let tipSideSeparation = 0.075
        static let tipMaxSeparation = 0.30
        static let emissionDebounce = 0.15
        static let repeatedTipTapCooldown = 0.15
    }

    private var session: GestureSession?
    private var lastEmission: GestureEvent?

    public init() {}

    public func reset() {
        session = nil
        lastEmission = nil
    }

    public func process(frame: TouchFrame) -> RecognizerResult {
        let activeContacts = frame.contacts.filter { $0.phase.isActiveSurfaceContact }

        guard !activeContacts.isEmpty else {
            defer { session = nil }
            guard let session else { return RecognizerResult(event: nil, suppressClicks: false) }
            guard !session.didEmitLiveTipTap else { return RecognizerResult(event: nil, suppressClicks: false) }
            let event = emitIfNotDebounced(session.classify())
            return RecognizerResult(event: event, suppressClicks: event != nil)
        }

        if session == nil {
            session = GestureSession(startTimestamp: frame.timestamp)
        }

        let shouldAttemptTerminalClassification = activeContacts.contains { $0.phase == .breakTouch }
        let event = emitIfNotDebounced(
            session?.append(
                timestamp: frame.timestamp,
                contacts: activeContacts,
                shouldAttemptTerminalClassification: shouldAttemptTerminalClassification
            )
        )
        let suppressClicks = event != nil || session?.hasTipTapCandidate == true
        return RecognizerResult(event: event, suppressClicks: suppressClicks)
    }

    private func emitIfNotDebounced(_ event: GestureEvent?) -> GestureEvent? {
        guard let event else { return nil }
        if let lastEmission,
           lastEmission.kind == event.kind,
           lastEmission.phase == event.phase,
           (event.timestamp - lastEmission.timestamp) < Thresholds.emissionDebounce {
            return nil
        }

        lastEmission = event
        return event
    }
}

private struct GestureSession {
    private(set) var startTimestamp: TimeInterval
    private(set) var lastTimestamp: TimeInterval
    private(set) var maxActiveCount = 0
    private(set) var snapshots: [SessionSnapshot] = []
    private(set) var traces: [Int: ContactTrace] = [:]
    private(set) var didEmitLiveTipTap = false
    private(set) var didArmThreeFingerSwipeDown = false
    private var tipTapCandidate: TipTapCandidate?
    private var lastLiveTipTap: LiveTipTapEmission?

    var hasTipTapCandidate: Bool {
        tipTapCandidate != nil
    }

    init(startTimestamp: TimeInterval) {
        self.startTimestamp = startTimestamp
        lastTimestamp = startTimestamp
    }

    mutating func append(
        timestamp: TimeInterval,
        contacts: [TouchContact],
        shouldAttemptTerminalClassification: Bool = false
    ) -> GestureEvent? {
        lastTimestamp = timestamp
        maxActiveCount = max(maxActiveCount, contacts.count)
        let sortedContacts = contacts.sorted { $0.identifier < $1.identifier }
        snapshots.append(SessionSnapshot(timestamp: timestamp, contacts: sortedContacts))

        for contact in sortedContacts {
            var trace = traces[contact.identifier]
                ?? ContactTrace(id: contact.identifier, firstTimestamp: timestamp, firstPosition: contact.position)
            trace.append(timestamp: timestamp, position: contact.position)
            traces[contact.identifier] = trace
        }

        if let event = classifyLiveTipTapIfNeeded() {
            didEmitLiveTipTap = true
            return event
        }

        if let event = classifyReadinessIfNeeded() {
            return event
        }

        if shouldAttemptTerminalClassification, !didEmitLiveTipTap {
            return classify()
        }

        return nil
    }

    func classify() -> GestureEvent? {
        if let event = classifyThreeFingerTap() { return event }
        if let event = classifyThreeFingerSwipeDown() { return event }
        if let event = classifyThreeFingerTipTap() { return event }
        if let event = classifyTipTap() { return event }
        return nil
    }

    private mutating func classifyReadinessIfNeeded() -> GestureEvent? {
        guard !didArmThreeFingerSwipeDown else { return nil }
        guard maxActiveCount == 3, traces.count == 3 else { return nil }
        guard let lastSnapshot = snapshots.last, lastSnapshot.contacts.count == 3 else { return nil }

        guard classifyThreeFingerSwipeDown() != nil else { return nil }
        didArmThreeFingerSwipeDown = true
        return GestureEvent(
            kind: .threeFingerSwipeDown,
            timestamp: lastTimestamp,
            phase: .armed
        )
    }

    private func classifyThreeFingerTap() -> GestureEvent? {
        guard maxActiveCount == 3, traces.count == 3 else { return nil }
        let duration = lastTimestamp - startTimestamp
        guard duration <= GestureRecognizer.Thresholds.tapDuration else { return nil }
        guard traces.values.allSatisfy({ $0.maxDistanceFromStart <= GestureRecognizer.Thresholds.tapMaxTravel }) else { return nil }

        let threeFingerSnapshots = snapshots.filter { $0.contacts.count == 3 }
        guard let first = threeFingerSnapshots.first, let last = threeFingerSnapshots.last else { return nil }

        let centroidTravel = first.centroid.distance(to: last.centroid)
        guard centroidTravel <= GestureRecognizer.Thresholds.tapCentroidTravel else { return nil }
        return GestureEvent(kind: .threeFingerTap, timestamp: lastTimestamp)
    }

    private func classifyThreeFingerSwipeDown() -> GestureEvent? {
        guard maxActiveCount == 3, traces.count == 3 else { return nil }
        let duration = lastTimestamp - startTimestamp
        guard duration <= GestureRecognizer.Thresholds.swipeDuration else { return nil }

        let threeFingerSnapshots = snapshots.filter { $0.contacts.count == 3 }
        guard let first = threeFingerSnapshots.first, let last = threeFingerSnapshots.last else { return nil }

        let dx = last.centroid.x - first.centroid.x
        let dy = last.centroid.y - first.centroid.y
        guard dy <= -GestureRecognizer.Thresholds.swipeMinVerticalTravel else { return nil }
        guard abs(dx) <= GestureRecognizer.Thresholds.swipeMaxHorizontalTravel else { return nil }
        return GestureEvent(
            kind: .threeFingerSwipeDown,
            timestamp: lastTimestamp,
            shouldPlayHaptic: !didArmThreeFingerSwipeDown
        )
    }

    private func classifyThreeFingerTipTap() -> GestureEvent? {
        guard maxActiveCount == 3, traces.count == 3 else { return nil }
        return classifyTipTapGesture(anchorCount: 2)
    }

    private func classifyTipTap() -> GestureEvent? {
        guard maxActiveCount == 2, traces.count == 2 else { return nil }
        return classifyTipTapGesture(anchorCount: 1)
    }

    private func classifyTipTapGesture(anchorCount: Int) -> GestureEvent? {
        let orderedTraces = orderedContactTraces()
        guard orderedTraces.count == anchorCount + 1 else { return nil }

        let anchors = Array(orderedTraces.prefix(anchorCount))
        guard let tip = orderedTraces.last else { return nil }

        let latestAnchorStart = anchors.map(\.firstTimestamp).max() ?? tip.firstTimestamp
        guard (tip.firstTimestamp - latestAnchorStart) >= GestureRecognizer.Thresholds.anchorLeadTime else { return nil }
        guard anchors.allSatisfy({ $0.duration >= GestureRecognizer.Thresholds.anchorMinDuration }) else { return nil }
        guard tip.duration <= GestureRecognizer.Thresholds.tipMaxDuration else { return nil }
        guard anchors.allSatisfy({ $0.maxDistanceFromStart <= GestureRecognizer.Thresholds.anchorMaxTravel }) else { return nil }
        guard tip.maxDistanceFromStart <= GestureRecognizer.Thresholds.tipMaxTravel else { return nil }
        guard anchors.allSatisfy({ tip.firstTimestamp <= $0.lastTimestamp }) else { return nil }

        let anchorReferencePositions = anchors.map { $0.position(closestTo: tip.firstTimestamp) }
        return makeTipTapEvent(
            anchorReferencePositions: anchorReferencePositions,
            tipFirstPosition: tip.firstPosition,
            timestamp: lastTimestamp
        )
    }

    private mutating func classifyLiveTipTapIfNeeded() -> GestureEvent? {
        guard snapshots.count >= 2 else { return nil }

        let previous = snapshots[snapshots.count - 2]
        let current = snapshots[snapshots.count - 1]

        switch (previous.contacts.count, current.contacts.count) {
        case (1, 2):
            startTipTapCandidate(previous: previous, current: current)
            return nil
        case (2, 2):
            updateTipTapCandidate(current: current)
            return nil
        case (2, 1):
            let event = finishTipTapCandidate(current: current)
            tipTapCandidate = nil
            return event
        case (2, 3):
            startTipTapCandidate(previous: previous, current: current)
            return nil
        case (3, 3):
            updateTipTapCandidate(current: current)
            return nil
        case (3, 2):
            let event = finishTipTapCandidate(current: current)
            tipTapCandidate = nil
            return event
        default:
            tipTapCandidate = nil
            return nil
        }
    }

    private mutating func startTipTapCandidate(previous: SessionSnapshot, current: SessionSnapshot) {
        let previousIDs = Set(previous.contacts.map { $0.identifier })
        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        let anchors = previous.contacts

        guard !anchors.isEmpty,
              let tip = current.contacts.first(where: { !previousIDs.contains($0.identifier) }),
              let candidate = makeTipTapCandidate(
                anchors: anchors,
                tip: tip,
                currentTimestamp: current.timestamp,
                currentByIdentifier: currentByIdentifier
              ) else {
            tipTapCandidate = nil
            return
        }

        tipTapCandidate = candidate
    }

    private mutating func updateTipTapCandidate(current: SessionSnapshot) {
        guard var candidate = tipTapCandidate else { return }
        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        for i in 0..<candidate.anchorIDs.count {
            guard let anchor = currentByIdentifier[candidate.anchorIDs[i]] else {
                tipTapCandidate = nil
                return
            }
            candidate.anchorMaxDistances[i] = max(
                candidate.anchorMaxDistances[i],
                anchor.position.distance(to: candidate.anchorReferencePositions[i])
            )
        }

        guard let tip = currentByIdentifier[candidate.tipID] else {
            tipTapCandidate = nil
            return
        }

        candidate.tipTrace.append(timestamp: current.timestamp, position: tip.position)
        tipTapCandidate = candidate
    }

    private func makeTipTapCandidate(
        anchors: [TouchContact],
        tip: TouchContact,
        currentTimestamp: TimeInterval,
        currentByIdentifier: [Int: TouchContact]
    ) -> TipTapCandidate? {
        let anchorTraces = anchors.compactMap { traces[$0.identifier] }
        guard anchorTraces.count == anchors.count else { return nil }

        let anchorReferencePositions = anchorTraces.map { $0.position(closestTo: currentTimestamp) }
        let anchorLeadDuration = currentTimestamp - (anchorTraces.map(\.firstTimestamp).max() ?? currentTimestamp)
        let anchorMaxDistances = anchors.enumerated().map { index, anchor in
            currentByIdentifier[anchor.identifier]!.position.distance(to: anchor.position)
        }

        return TipTapCandidate(
            anchorIDs: anchors.map(\.identifier),
            tipID: tip.identifier,
            anchorLeadDuration: anchorLeadDuration,
            anchorReferencePositions: anchorReferencePositions,
            anchorMaxDistances: anchorMaxDistances,
            tipTrace: ContactTrace(id: tip.identifier, firstTimestamp: currentTimestamp, firstPosition: tip.position)
        )
    }

    private mutating func finishTipTapCandidate(current: SessionSnapshot) -> GestureEvent? {
        guard let candidate = tipTapCandidate else { return nil }

        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        guard candidate.anchorIDs.allSatisfy({ currentByIdentifier[$0] != nil }) else { return nil }

        guard candidate.anchorLeadDuration >= GestureRecognizer.Thresholds.anchorLeadTime else { return nil }
        let anchorDuration = candidate.anchorLeadDuration + (current.timestamp - candidate.tipTrace.firstTimestamp)
        guard anchorDuration >= GestureRecognizer.Thresholds.anchorMinDuration else { return nil }
        guard candidate.tipTrace.duration <= GestureRecognizer.Thresholds.tipMaxDuration else { return nil }
        guard candidate.tipTrace.maxDistanceFromStart <= GestureRecognizer.Thresholds.tipMaxTravel else { return nil }

        for i in 0..<candidate.anchorIDs.count {
            let anchorDistanceAtFinish = currentByIdentifier[candidate.anchorIDs[i]]!.position.distance(
                to: candidate.anchorReferencePositions[i])
            guard max(candidate.anchorMaxDistances[i], anchorDistanceAtFinish)
                <= GestureRecognizer.Thresholds.anchorMaxTravel else {
                return nil
            }
        }

        guard let event = makeTipTapEvent(
            anchorReferencePositions: candidate.anchorReferencePositions,
            tipFirstPosition: candidate.tipTrace.firstPosition,
            timestamp: current.timestamp
        ) else {
            return nil
        }

        let kind = event.kind
        if let lastLiveTipTap,
           lastLiveTipTap.kind == kind,
           Set(lastLiveTipTap.anchorIDs) == Set(candidate.anchorIDs),
           current.timestamp - lastLiveTipTap.timestamp < GestureRecognizer.Thresholds.repeatedTipTapCooldown {
            return nil
        }

        lastLiveTipTap = LiveTipTapEmission(
            kind: kind,
            anchorIDs: candidate.anchorIDs,
            timestamp: current.timestamp
        )
        return event
    }

    private func orderedContactTraces() -> [ContactTrace] {
        traces.values.sorted { lhs, rhs in
            if lhs.firstTimestamp == rhs.firstTimestamp {
                return lhs.id < rhs.id
            }
            return lhs.firstTimestamp < rhs.firstTimestamp
        }
    }

    private func makeTipTapEvent(
        anchorReferencePositions: [TouchPoint],
        tipFirstPosition: TouchPoint,
        timestamp: TimeInterval
    ) -> GestureEvent? {
        let anchorCentroid = centroid(of: anchorReferencePositions)
        guard anchorCentroid.distance(to: tipFirstPosition) <= GestureRecognizer.Thresholds.tipMaxSeparation else {
            return nil
        }

        let deltaX = tipFirstPosition.x - anchorCentroid.x
        guard let kind = tipTapKind(anchorCount: anchorReferencePositions.count, deltaX: deltaX) else {
            return nil
        }

        return GestureEvent(kind: kind, timestamp: timestamp)
    }

    private func tipTapKind(anchorCount: Int, deltaX: Double) -> GestureKind? {
        switch anchorCount {
        case 1:
            guard abs(deltaX) >= GestureRecognizer.Thresholds.tipSideSeparation else { return nil }
            return deltaX < 0 ? .twoFingerTipTapLeft : .twoFingerTipTapRight
        case 2:
            guard deltaX < -GestureRecognizer.Thresholds.tipSideSeparation else { return nil }
            return .threeFingerTipTapLeft
        default:
            return nil
        }
    }

    private func centroid(of points: [TouchPoint]) -> TouchPoint {
        let sum = points.reduce((x: 0.0, y: 0.0)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return TouchPoint(
            x: sum.x / Double(points.count),
            y: sum.y / Double(points.count)
        )
    }
}

private struct TipTapCandidate {
    var anchorIDs: [Int]
    var tipID: Int
    var anchorLeadDuration: TimeInterval
    var anchorReferencePositions: [TouchPoint]
    var anchorMaxDistances: [Double]
    var tipTrace: ContactTrace
}

private struct LiveTipTapEmission {
    var kind: GestureKind
    var anchorIDs: [Int]
    var timestamp: TimeInterval
}

private struct SessionSnapshot {
    var timestamp: TimeInterval
    var contacts: [TouchContact]

    var centroid: TouchPoint {
        let sum = contacts.reduce((x: 0.0, y: 0.0)) { partial, contact in
            (partial.x + contact.position.x, partial.y + contact.position.y)
        }
        return TouchPoint(x: sum.x / Double(contacts.count), y: sum.y / Double(contacts.count))
    }
}

private struct ContactTrace {
    struct Sample {
        var timestamp: TimeInterval
        var position: TouchPoint
    }

    let id: Int
    let firstTimestamp: TimeInterval
    let firstPosition: TouchPoint
    private(set) var lastTimestamp: TimeInterval
    private(set) var samples: [Sample]

    init(id: Int, firstTimestamp: TimeInterval, firstPosition: TouchPoint) {
        self.id = id
        self.firstTimestamp = firstTimestamp
        self.firstPosition = firstPosition
        lastTimestamp = firstTimestamp
        samples = [Sample(timestamp: firstTimestamp, position: firstPosition)]
    }

    var duration: TimeInterval {
        lastTimestamp - firstTimestamp
    }

    var maxDistanceFromStart: Double {
        samples.map { $0.position.distance(to: firstPosition) }.max() ?? 0
    }

    mutating func append(timestamp: TimeInterval, position: TouchPoint) {
        lastTimestamp = timestamp
        samples.append(Sample(timestamp: timestamp, position: position))
    }

    func position(closestTo timestamp: TimeInterval) -> TouchPoint {
        samples.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })?.position ?? firstPosition
    }
}
