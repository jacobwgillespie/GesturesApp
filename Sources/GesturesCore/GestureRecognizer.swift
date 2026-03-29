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
    private var threeFingerTipTapCandidate: ThreeFingerTipTapCandidate?
    private var lastLiveTipTap: LiveTipTapEmission?
    private var lastLiveThreeFingerTipTap: LiveThreeFingerTipTapEmission?

    var hasTipTapCandidate: Bool {
        tipTapCandidate != nil || threeFingerTipTapCandidate != nil
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
        let orderedTraces = traces.values.sorted { lhs, rhs in
            if lhs.firstTimestamp == rhs.firstTimestamp {
                return lhs.id < rhs.id
            }
            return lhs.firstTimestamp < rhs.firstTimestamp
        }

        let anchors = Array(orderedTraces.prefix(2))
        guard let tip = orderedTraces.last else { return nil }

        let latestAnchorStart = max(anchors[0].firstTimestamp, anchors[1].firstTimestamp)
        guard (tip.firstTimestamp - latestAnchorStart) >= GestureRecognizer.Thresholds.anchorLeadTime else { return nil }
        guard anchors.allSatisfy({ $0.duration >= GestureRecognizer.Thresholds.anchorMinDuration }) else { return nil }
        guard tip.duration <= GestureRecognizer.Thresholds.tipMaxDuration else { return nil }
        guard anchors.allSatisfy({ $0.maxDistanceFromStart <= GestureRecognizer.Thresholds.anchorMaxTravel }) else { return nil }
        guard tip.maxDistanceFromStart <= GestureRecognizer.Thresholds.tipMaxTravel else { return nil }
        guard anchors.allSatisfy({ tip.firstTimestamp <= $0.lastTimestamp }) else { return nil }

        let anchorPos0 = anchors[0].position(closestTo: tip.firstTimestamp)
        let anchorPos1 = anchors[1].position(closestTo: tip.firstTimestamp)
        let anchorCentroid = TouchPoint(
            x: (anchorPos0.x + anchorPos1.x) / 2,
            y: (anchorPos0.y + anchorPos1.y) / 2
        )
        guard anchorCentroid.distance(to: tip.firstPosition) <= GestureRecognizer.Thresholds.tipMaxSeparation else {
            return nil
        }
        let deltaX = tip.firstPosition.x - anchorCentroid.x
        guard deltaX < -GestureRecognizer.Thresholds.tipSideSeparation else { return nil }

        return GestureEvent(kind: .threeFingerTipTapLeft, timestamp: lastTimestamp)
    }

    private func classifyTipTap() -> GestureEvent? {
        guard maxActiveCount == 2, traces.count == 2 else { return nil }
        let orderedTraces = traces.values.sorted { lhs, rhs in
            if lhs.firstTimestamp == rhs.firstTimestamp {
                return lhs.id < rhs.id
            }
            return lhs.firstTimestamp < rhs.firstTimestamp
        }

        guard let anchor = orderedTraces.first, let tip = orderedTraces.last else { return nil }
        guard (tip.firstTimestamp - anchor.firstTimestamp) >= GestureRecognizer.Thresholds.anchorLeadTime else { return nil }
        guard anchor.duration >= GestureRecognizer.Thresholds.anchorMinDuration else { return nil }
        guard tip.duration <= GestureRecognizer.Thresholds.tipMaxDuration else { return nil }
        guard anchor.maxDistanceFromStart <= GestureRecognizer.Thresholds.anchorMaxTravel else { return nil }
        guard tip.maxDistanceFromStart <= GestureRecognizer.Thresholds.tipMaxTravel else { return nil }
        guard tip.firstTimestamp <= anchor.lastTimestamp else { return nil }

        let anchorPosition = anchor.position(closestTo: tip.firstTimestamp)
        guard anchorPosition.distance(to: tip.firstPosition) <= GestureRecognizer.Thresholds.tipMaxSeparation else {
            return nil
        }
        let deltaX = tip.firstPosition.x - anchorPosition.x
        guard abs(deltaX) >= GestureRecognizer.Thresholds.tipSideSeparation else { return nil }

        let kind: GestureKind = deltaX < 0 ? .twoFingerTipTapLeft : .twoFingerTipTapRight
        return GestureEvent(kind: kind, timestamp: lastTimestamp)
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
            tipTapCandidate = nil
            startThreeFingerTipTapCandidate(previous: previous, current: current)
            return nil
        case (3, 3):
            updateThreeFingerTipTapCandidate(current: current)
            return nil
        case (3, 2):
            let event = finishThreeFingerTipTapCandidate(current: current)
            threeFingerTipTapCandidate = nil
            return event
        default:
            tipTapCandidate = nil
            threeFingerTipTapCandidate = nil
            return nil
        }
    }

    private mutating func startTipTapCandidate(previous: SessionSnapshot, current: SessionSnapshot) {
        guard let anchor = previous.contacts.first else {
            tipTapCandidate = nil
            return
        }

        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        guard let currentAnchor = currentByIdentifier[anchor.identifier],
              let tip = current.contacts.first(where: { $0.identifier != anchor.identifier }),
              let anchorTrace = traces[anchor.identifier] else {
            tipTapCandidate = nil
            return
        }

        tipTapCandidate = TipTapCandidate(
            anchorID: anchor.identifier,
            tipID: tip.identifier,
            anchorLeadDuration: current.timestamp - anchorTrace.firstTimestamp,
            anchorReferencePosition: anchorTrace.position(closestTo: current.timestamp),
            anchorMaxDistance: currentAnchor.position.distance(to: anchor.position),
            tipTrace: ContactTrace(id: tip.identifier, firstTimestamp: current.timestamp, firstPosition: tip.position)
        )
    }

    private mutating func updateTipTapCandidate(current: SessionSnapshot) {
        guard var candidate = tipTapCandidate else { return }
        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        guard let anchor = currentByIdentifier[candidate.anchorID],
              let tip = currentByIdentifier[candidate.tipID] else {
            tipTapCandidate = nil
            return
        }

        candidate.anchorMaxDistance = max(
            candidate.anchorMaxDistance,
            anchor.position.distance(to: candidate.anchorReferencePosition)
        )
        candidate.tipTrace.append(timestamp: current.timestamp, position: tip.position)
        tipTapCandidate = candidate
    }

    private mutating func startThreeFingerTipTapCandidate(previous: SessionSnapshot, current: SessionSnapshot) {
        let previousIDs = Set(previous.contacts.map { $0.identifier })
        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })
        guard let tip = current.contacts.first(where: { !previousIDs.contains($0.identifier) }) else {
            threeFingerTipTapCandidate = nil
            return
        }

        let anchors = previous.contacts
        guard anchors.count == 2,
              let anchorTrace0 = traces[anchors[0].identifier],
              let anchorTrace1 = traces[anchors[1].identifier] else {
            threeFingerTipTapCandidate = nil
            return
        }

        let anchorRefPos0 = anchorTrace0.position(closestTo: current.timestamp)
        let anchorRefPos1 = anchorTrace1.position(closestTo: current.timestamp)

        threeFingerTipTapCandidate = ThreeFingerTipTapCandidate(
            anchorIDs: [anchors[0].identifier, anchors[1].identifier],
            tipID: tip.identifier,
            anchorLeadDuration: current.timestamp - max(anchorTrace0.firstTimestamp, anchorTrace1.firstTimestamp),
            anchorReferencePositions: [anchorRefPos0, anchorRefPos1],
            anchorMaxDistances: [
                currentByIdentifier[anchors[0].identifier]!.position.distance(to: anchors[0].position),
                currentByIdentifier[anchors[1].identifier]!.position.distance(to: anchors[1].position),
            ],
            tipTrace: ContactTrace(id: tip.identifier, firstTimestamp: current.timestamp, firstPosition: tip.position)
        )
    }

    private mutating func updateThreeFingerTipTapCandidate(current: SessionSnapshot) {
        guard var candidate = threeFingerTipTapCandidate else { return }
        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.contacts.map { ($0.identifier, $0) })

        for i in 0..<candidate.anchorIDs.count {
            guard let anchor = currentByIdentifier[candidate.anchorIDs[i]] else {
                threeFingerTipTapCandidate = nil
                return
            }
            candidate.anchorMaxDistances[i] = max(
                candidate.anchorMaxDistances[i],
                anchor.position.distance(to: candidate.anchorReferencePositions[i])
            )
        }

        guard let tip = currentByIdentifier[candidate.tipID] else {
            threeFingerTipTapCandidate = nil
            return
        }

        candidate.tipTrace.append(timestamp: current.timestamp, position: tip.position)
        threeFingerTipTapCandidate = candidate
    }

    private mutating func finishThreeFingerTipTapCandidate(current: SessionSnapshot) -> GestureEvent? {
        guard let candidate = threeFingerTipTapCandidate else { return nil }

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

        let anchorCentroid = TouchPoint(
            x: (candidate.anchorReferencePositions[0].x + candidate.anchorReferencePositions[1].x) / 2,
            y: (candidate.anchorReferencePositions[0].y + candidate.anchorReferencePositions[1].y) / 2
        )
        guard anchorCentroid.distance(to: candidate.tipTrace.firstPosition)
            <= GestureRecognizer.Thresholds.tipMaxSeparation else {
            return nil
        }
        let deltaX = candidate.tipTrace.firstPosition.x - anchorCentroid.x
        guard deltaX < -GestureRecognizer.Thresholds.tipSideSeparation else { return nil }

        let kind: GestureKind = .threeFingerTipTapLeft
        if let lastLiveThreeFingerTipTap,
           lastLiveThreeFingerTipTap.kind == kind,
           Set(lastLiveThreeFingerTipTap.anchorIDs) == Set(candidate.anchorIDs),
           current.timestamp - lastLiveThreeFingerTipTap.timestamp < GestureRecognizer.Thresholds.repeatedTipTapCooldown {
            return nil
        }

        lastLiveThreeFingerTipTap = LiveThreeFingerTipTapEmission(
            kind: kind,
            anchorIDs: candidate.anchorIDs,
            timestamp: current.timestamp
        )
        return GestureEvent(kind: kind, timestamp: current.timestamp)
    }

    private mutating func finishTipTapCandidate(current: SessionSnapshot) -> GestureEvent? {
        guard let candidate = tipTapCandidate else { return nil }
        guard let anchor = current.contacts.first(where: { $0.identifier == candidate.anchorID }) else { return nil }

        let anchorDuration = candidate.anchorLeadDuration + (current.timestamp - candidate.tipTrace.firstTimestamp)
        guard candidate.anchorLeadDuration >= GestureRecognizer.Thresholds.anchorLeadTime else { return nil }
        guard anchorDuration >= GestureRecognizer.Thresholds.anchorMinDuration else { return nil }
        guard candidate.tipTrace.duration <= GestureRecognizer.Thresholds.tipMaxDuration else { return nil }
        guard candidate.anchorMaxDistance <= GestureRecognizer.Thresholds.anchorMaxTravel else { return nil }
        guard candidate.tipTrace.maxDistanceFromStart <= GestureRecognizer.Thresholds.tipMaxTravel else { return nil }

        let anchorDistanceAtFinish = anchor.position.distance(to: candidate.anchorReferencePosition)
        guard max(candidate.anchorMaxDistance, anchorDistanceAtFinish) <= GestureRecognizer.Thresholds.anchorMaxTravel else {
            return nil
        }

        let deltaX = candidate.tipTrace.firstPosition.x - candidate.anchorReferencePosition.x
        guard candidate.anchorReferencePosition.distance(to: candidate.tipTrace.firstPosition)
            <= GestureRecognizer.Thresholds.tipMaxSeparation else {
            return nil
        }
        guard abs(deltaX) >= GestureRecognizer.Thresholds.tipSideSeparation else { return nil }

        let kind: GestureKind = deltaX < 0 ? .twoFingerTipTapLeft : .twoFingerTipTapRight
        if let lastLiveTipTap,
           lastLiveTipTap.kind == kind,
           lastLiveTipTap.anchorID == candidate.anchorID,
           current.timestamp - lastLiveTipTap.timestamp < GestureRecognizer.Thresholds.repeatedTipTapCooldown {
            return nil
        }

        lastLiveTipTap = LiveTipTapEmission(
            kind: kind,
            anchorID: candidate.anchorID,
            timestamp: current.timestamp
        )
        return GestureEvent(kind: kind, timestamp: current.timestamp)
    }
}

private struct TipTapCandidate {
    var anchorID: Int
    var tipID: Int
    var anchorLeadDuration: TimeInterval
    var anchorReferencePosition: TouchPoint
    var anchorMaxDistance: Double
    var tipTrace: ContactTrace
}

private struct ThreeFingerTipTapCandidate {
    var anchorIDs: [Int]
    var tipID: Int
    var anchorLeadDuration: TimeInterval
    var anchorReferencePositions: [TouchPoint]
    var anchorMaxDistances: [Double]
    var tipTrace: ContactTrace
}

private struct LiveThreeFingerTipTapEmission {
    var kind: GestureKind
    var anchorIDs: [Int]
    var timestamp: TimeInterval
}

private struct LiveTipTapEmission {
    var kind: GestureKind
    var anchorID: Int
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
