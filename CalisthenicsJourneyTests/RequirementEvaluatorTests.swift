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
