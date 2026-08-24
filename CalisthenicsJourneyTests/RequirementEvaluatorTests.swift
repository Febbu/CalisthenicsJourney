import XCTest
@testable import CalisthenicsJourney

@MainActor
final class RequirementEvaluatorTests: XCTestCase {
    func testOneNumericDemonstrationSatisfiesEachMetricDespiteLegacyConfirmationCount() {
        let reps = fixture(metric: .reps)
        let seconds = fixture(metric: .seconds)
        let weighted = fixture(metric: .weightAndReps)
        let owner = JourneyLevel(number: 1, name: "Legacy")
        let requirements = [
            requirement(variation: reps.variation, kind: .reps, targetReps: 5, confirmationsNeeded: 99, owner: owner),
            requirement(variation: seconds.variation, kind: .seconds, targetSeconds: 10, confirmationsNeeded: 2, owner: owner),
            requirement(variation: weighted.variation, kind: .weightAndReps, targetReps: 5, targetWeight: 20, owner: owner)
        ]
        let sessions = [
            session(reps.variation, reps: 5),
            session(seconds.variation, seconds: 10),
            session(weighted.variation, weight: 20, reps: 5)
        ]

        for requirement in requirements {
            let result = RequirementEvaluator.evaluate(requirement, against: sessions)
            XCTAssertTrue(result.isSatisfied)
            XCTAssertEqual(result.qualifyingEvidenceIDs.count, 1)
        }
        XCTAssertEqual(requirements[0].confirmationsNeeded, 99)
    }

    func testAttemptRequirementRequiresSuccessfulAttempt() {
        let movement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let requirement = requirement(variation: movement.variation, kind: .successfulAttempt, owner: owner)

        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, effortKind: .attempt)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, reps: 20, effortKind: .attempt)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, effortKind: .attempt, attemptOutcome: .unsuccessful)]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, effortKind: .attempt, attemptOutcome: .successful)]).isSatisfied)
    }

    func testNumericRequirementIgnoresAttemptOutcomeAndMalformedMetrics() {
        let movement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let requirement = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)

        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, effortKind: .numeric, attemptOutcome: .successful)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, seconds: 10, metric: .seconds)]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, reps: 5)]).isSatisfied)
    }

    func testMalformedRequirementSemanticsFailClosedWhileNilLegacyKindRemainsCompatible() {
        let movement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let proof = [session(movement.variation, reps: 5)]

        let legacy = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)
        legacy.evidenceKindRaw = nil
        XCTAssertTrue(RequirementEvaluator.evaluate(legacy, against: proof).isSatisfied)

        let invalidKind = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)
        invalidKind.evidenceKindRaw = "futureUnknownKind"
        XCTAssertFalse(RequirementEvaluator.evaluate(invalidKind, against: proof).isSatisfied)

        let invalidSide = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)
        invalidSide.sideRaw = "eitherSide"
        XCTAssertFalse(RequirementEvaluator.evaluate(invalidSide, against: proof).isSatisfied)

        let invalidMetric = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)
        invalidMetric.metricRaw = "futureUnknownMetric"
        XCTAssertFalse(RequirementEvaluator.evaluate(invalidMetric, against: proof).isSatisfied)
    }

    func testWeightAndRepsRequiresBothValuesAndBothThresholds() {
        let movement = fixture(metric: .weightAndReps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let requirement = requirement(
            variation: movement.variation,
            kind: .weightAndReps,
            targetReps: 5,
            targetWeight: 20,
            owner: owner
        )

        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, weight: 20, reps: 4)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, weight: 19, reps: 5)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, reps: 5)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, weight: 20)]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [session(movement.variation, weight: 20, reps: 5)]).isSatisfied)
    }

    func testExactVariationAndSideMustMatch() {
        let family = Exercise(name: "Family", metric: .reps)
        let first = ExerciseVariation(name: "First", metric: .reps, exercise: family)
        let second = ExerciseVariation(name: "Second", metric: .reps, exercise: family)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let left = requirement(variation: first, kind: .reps, targetReps: 5, side: .left, owner: owner)
        let right = requirement(variation: first, kind: .reps, targetReps: 5, side: .right, owner: owner)
        let general = requirement(variation: first, kind: .reps, targetReps: 5, owner: owner)

        XCTAssertTrue(RequirementEvaluator.evaluate(left, against: [session(first, reps: 5, side: .left)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(right, against: [session(first, reps: 5, side: .left)]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(right, against: [session(first, reps: 5, side: .right)]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(general, against: [session(first, reps: 5)]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(general, against: [session(second, reps: 50)]).isSatisfied)
    }

    func testSeparateLeftAndRightRequirementsCanMasterOneOwner() {
        let movement = fixture(metric: .reps)
        let stage = SkillStage(name: "Both sides", orderIndex: 0)
        let left = requirement(variation: movement.variation, kind: .reps, targetReps: 3, side: .left, owner: stage)
        let right = requirement(variation: movement.variation, kind: .reps, targetReps: 3, side: .right, owner: stage)

        XCTAssertTrue(RequirementEvaluator.areAllMastered(
            [left, right],
            against: [session(movement.variation, reps: 3, side: .left), session(movement.variation, reps: 3, side: .right)]
        ))
    }

    func testExplicitImplicationPropagatesEvidenceButOrderAndUnrelatedRequirementsDoNot() {
        let movement = fixture(metric: .reps)
        let firstStage = SkillStage(name: "Earlier", orderIndex: 0)
        let laterStage = SkillStage(name: "Later", orderIndex: 5)
        let unrelatedStage = SkillStage(name: "Independent", orderIndex: 1)
        let lower = requirement(variation: movement.variation, kind: .reps, targetReps: 1, owner: firstStage)
        let middle = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: firstStage)
        let higher = requirement(variation: movement.variation, kind: .reps, targetReps: 10, owner: laterStage)
        let unrelated = requirement(variation: movement.variation, kind: .successfulAttempt, owner: unrelatedStage)
        let implications = [RequirementImplication(source: higher, implies: middle), RequirementImplication(source: middle, implies: lower)]
        let history = [session(movement.variation, reps: 10)]

        let lowerResult = RequirementEvaluator.evaluate(lower, against: history, implications: implications)
        XCTAssertTrue(lowerResult.isSatisfied)
        XCTAssertEqual(lowerResult.qualifyingEvidenceIDs.count, 1)
        XCTAssertEqual(lowerResult.impliedByRequirementIDs, [middle.id])
        XCTAssertFalse(RequirementEvaluator.evaluate(unrelated, against: history, implications: implications).isSatisfied)
    }

    func testExplicitImplicationAndEvidenceCanCrossSkillsAndOwners() {
        let movement = fixture(metric: .seconds)
        let firstSkill = Skill(name: "First", emoji: "")
        let secondSkill = Skill(name: "Second", emoji: "")
        let sourceStage = SkillStage(name: "Source", orderIndex: 0, skill: firstSkill)
        let targetStage = SkillStage(name: "Target", orderIndex: 0, skill: secondSkill)
        let source = requirement(variation: movement.variation, kind: .seconds, targetSeconds: 10, owner: sourceStage)
        let target = requirement(variation: movement.variation, kind: .seconds, targetSeconds: 5, owner: targetStage)
        let edge = RequirementImplication(source: source, implies: target)
        let history = [session(movement.variation, seconds: 10)]

        XCTAssertTrue(RequirementEvaluator.evaluate(source, against: history, implications: [edge]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(target, against: history, implications: [edge]).isSatisfied)
    }

    func testDirectImplicationAcrossDifferentVariations() throws {
        let sourceMovement = fixture(metric: .reps)
        let targetMovement = fixture(metric: .reps)
        let sourceStage = SkillStage(name: "Source", orderIndex: 0)
        let targetStage = SkillStage(name: "Target", orderIndex: 1)
        let source = requirement(variation: sourceMovement.variation, kind: .reps, targetReps: 5, owner: sourceStage)
        let target = requirement(variation: targetMovement.variation, kind: .reps, targetReps: 1, owner: targetStage)
        let history = [session(sourceMovement.variation, reps: 5)]
        let proofID = try XCTUnwrap(history[0].exerciseLogs.first?.sets.first?.id)

        XCTAssertFalse(RequirementEvaluator.evaluate(target, against: history).isSatisfied)
        let result = RequirementEvaluator.evaluate(
            target,
            against: history,
            implications: [RequirementImplication(source: source, implies: target)]
        )
        XCTAssertTrue(result.isSatisfied)
        XCTAssertTrue(result.directEvidenceIDs.isEmpty)
        XCTAssertEqual(result.impliedEvidenceIDs, [proofID])
        XCTAssertEqual(result.impliedByRequirementIDs, [source.id])
    }

    func testTransitiveImplicationPreservesOriginalEvidenceAndImmediateSources() throws {
        let aMovement = fixture(metric: .reps)
        let bMovement = fixture(metric: .reps)
        let cMovement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let a = requirement(variation: aMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let b = requirement(variation: bMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let c = requirement(variation: cMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let history = [session(aMovement.variation, reps: 5)]
        let proofID = try XCTUnwrap(history[0].exerciseLogs.first?.sets.first?.id)
        let edges = [RequirementImplication(source: a, implies: b), RequirementImplication(source: b, implies: c)]

        let bResult = RequirementEvaluator.evaluate(b, against: history, implications: edges)
        let cResult = RequirementEvaluator.evaluate(c, against: history, implications: edges)
        XCTAssertEqual(bResult.impliedEvidenceIDs, [proofID])
        XCTAssertEqual(bResult.impliedByRequirementIDs, [a.id])
        XCTAssertEqual(cResult.impliedEvidenceIDs, [proofID])
        XCTAssertEqual(cResult.impliedByRequirementIDs, [b.id])
    }

    func testImplicationCyclesDoNotFabricateMasteryOrRecurseForever() {
        let aMovement = fixture(metric: .reps)
        let bMovement = fixture(metric: .reps)
        let cMovement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let a = requirement(variation: aMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let b = requirement(variation: bMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let c = requirement(variation: cMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let twoCycle = [RequirementImplication(source: a, implies: b), RequirementImplication(source: b, implies: a)]
        let longCycle = twoCycle + [RequirementImplication(source: b, implies: c), RequirementImplication(source: c, implies: a)]

        XCTAssertFalse(RequirementEvaluator.evaluate(a, against: [], implications: twoCycle).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(b, against: [], implications: twoCycle).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(a, against: [], implications: longCycle).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(b, against: [session(aMovement.variation, reps: 5)], implications: twoCycle).isSatisfied)
    }

    func testDiamondAndDuplicateImplicationsDeduplicateEvidenceDeterministically() throws {
        let movements = (0..<4).map { _ in fixture(metric: .reps) }
        let owner = JourneyLevel(number: 1, name: "Owner")
        let a = requirement(variation: movements[0].variation, kind: .reps, targetReps: 5, owner: owner)
        let b = requirement(variation: movements[1].variation, kind: .reps, targetReps: 5, owner: owner)
        let c = requirement(variation: movements[2].variation, kind: .reps, targetReps: 5, owner: owner)
        let d = requirement(variation: movements[3].variation, kind: .reps, targetReps: 5, owner: owner)
        let history = [session(movements[0].variation, reps: 5)]
        let proofID = try XCTUnwrap(history[0].exerciseLogs.first?.sets.first?.id)
        let edges = [
            RequirementImplication(source: a, implies: b),
            RequirementImplication(source: a, implies: b),
            RequirementImplication(source: a, implies: c),
            RequirementImplication(source: b, implies: d),
            RequirementImplication(source: c, implies: d)
        ]

        let bResult = RequirementEvaluator.evaluate(b, against: history, implications: edges)
        XCTAssertEqual(bResult.qualifyingEvidenceIDs, [proofID])
        XCTAssertEqual(bResult.impliedByRequirementIDs, [a.id])

        let firstDResult = RequirementEvaluator.evaluate(d, against: history, implications: edges)
        let secondDResult = RequirementEvaluator.evaluate(d, against: history, implications: Array(edges.reversed()))
        XCTAssertEqual(firstDResult.qualifyingEvidenceIDs, [proofID])
        XCTAssertEqual(firstDResult.impliedByRequirementIDs, [b.id, c.id].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(firstDResult, secondDResult)
    }

    func testDirectAndImpliedRoutesAreReportedSeparatelyAndUnionIsDeduplicated() throws {
        let sourceMovement = fixture(metric: .reps)
        let targetMovement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let source = requirement(variation: sourceMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let target = requirement(variation: targetMovement.variation, kind: .reps, targetReps: 5, owner: owner)
        let sourceSession = session(sourceMovement.variation, reps: 5)
        let targetSession = session(targetMovement.variation, reps: 5)
        let sourceID = try XCTUnwrap(sourceSession.exerciseLogs.first?.sets.first?.id)
        let targetID = try XCTUnwrap(targetSession.exerciseLogs.first?.sets.first?.id)

        let result = RequirementEvaluator.evaluate(
            target,
            against: [sourceSession, targetSession],
            implications: [RequirementImplication(source: source, implies: target)]
        )
        XCTAssertEqual(result.directEvidenceIDs, [targetID])
        XCTAssertEqual(result.impliedEvidenceIDs, [sourceID])
        XCTAssertEqual(result.qualifyingEvidenceIDs, [sourceID, targetID].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(result.impliedByRequirementIDs, [source.id])
    }

    func testEvidenceIsReusableAcrossOwnersAndUnaffectedByRenaming() {
        let movement = fixture(metric: .reps)
        let firstStage = SkillStage(name: "First owner", orderIndex: 0)
        let secondStage = SkillStage(name: "Second owner", orderIndex: 0)
        let first = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: firstStage)
        let second = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: secondStage)
        let history = [session(movement.variation, reps: 5)]

        movement.exercise.name = "Renamed family"
        movement.variation.name = "Renamed variation"

        XCTAssertTrue(RequirementEvaluator.evaluate(first, against: history).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(second, against: history).isSatisfied)
    }

    func testReevaluationTracksEvidenceRemovalAndPreservesOtherProof() {
        let movement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let requirement = requirement(variation: movement.variation, kind: .reps, targetReps: 10, owner: owner)
        let strong = session(movement.variation, reps: 10)
        let otherStrong = session(movement.variation, reps: 12)
        let weak = session(movement.variation, reps: 2)

        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [strong, weak]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [weak]).isSatisfied)
        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [otherStrong, weak]).isSatisfied)
    }

    func testUnfinishedAndPartialEvidenceQualifiesWhileEmptyRowDoesNot() {
        let movement = fixture(metric: .reps)
        let owner = JourneyLevel(number: 1, name: "Owner")
        let requirement = requirement(variation: movement.variation, kind: .reps, targetReps: 5, owner: owner)
        let unfinished = session(movement.variation, reps: 5, completed: false)
        let empty = session(movement.variation)

        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [unfinished]).isSatisfied)
        XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: [empty]).isSatisfied)
    }

    private func fixture(metric: ExerciseMetric) -> (exercise: Exercise, variation: ExerciseVariation) {
        let exercise = Exercise(name: "Family", metric: metric)
        return (exercise, ExerciseVariation(name: "Exact", metric: metric, exercise: exercise))
    }

    private func requirement(
        variation: ExerciseVariation,
        kind: RequirementEvidenceKind,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil,
        side: PerformanceSide = .notApplicable,
        confirmationsNeeded: Int = 2,
        owner: JourneyLevel
    ) -> Requirement {
        Requirement(title: "Requirement", exerciseID: variation.exercise?.id, variationID: variation.id, metric: legacyMetric(kind), evidenceKind: kind, side: side, targetReps: targetReps, targetWeight: targetWeight, targetSeconds: targetSeconds, confirmationsNeeded: confirmationsNeeded, journeyLevel: owner)
    }

    private func requirement(
        variation: ExerciseVariation,
        kind: RequirementEvidenceKind,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil,
        side: PerformanceSide = .notApplicable,
        owner: SkillStage
    ) -> Requirement {
        Requirement(title: "Requirement", exerciseID: variation.exercise?.id, variationID: variation.id, metric: legacyMetric(kind), evidenceKind: kind, side: side, targetReps: targetReps, targetWeight: targetWeight, targetSeconds: targetSeconds, skillStage: owner)
    }

    private func legacyMetric(_ kind: RequirementEvidenceKind) -> RequirementMetric {
        switch kind {
        case .reps, .successfulAttempt: return .reps
        case .seconds: return .seconds
        case .weightAndReps: return .weightAndReps
        }
    }

    private func session(
        _ variation: ExerciseVariation,
        weight: Double? = nil,
        reps: Int? = nil,
        seconds: Int? = nil,
        metric: ExerciseMetric? = nil,
        side: PerformanceSide = .notApplicable,
        effortKind: EffortKind = .numeric,
        attemptOutcome: AttemptOutcome? = nil,
        completed: Bool = true
    ) -> WorkoutSession {
        let workout = WorkoutSession(workoutName: "Workout")
        if completed { workout.completedAt = .now }
        let log = ExerciseLog(exercise: variation.exercise!, variation: variation, orderIndex: 0, session: workout)
        let set = SetLog(setNumber: 1, weight: weight, reps: reps, seconds: seconds, metric: metric, side: side, effortKind: effortKind, attemptOutcome: attemptOutcome, variation: variation, exerciseLog: log)
        log.sets = [set]
        workout.exerciseLogs = [log]
        return workout
    }
}
