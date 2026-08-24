import XCTest
@testable import CalisthenicsJourney

@MainActor
final class ProgressionEngineTests: XCTestCase {
    func testStageRequiresAllExplicitRequirementsIncludingBothSides() {
        let skill = Skill(name: "Skill", emoji: "")
        let stage = SkillStage(name: "Stage", orderIndex: 0, skill: skill)
        let movement = fixture(metric: .reps)
        stage.requirements = [
            requirement(movement.variation, target: 3, side: .left, stage: stage),
            requirement(movement.variation, target: 3, side: .right, stage: stage)
        ]

        XCTAssertFalse(ProgressionEngine.isMastered(stage, against: [session(movement.variation, reps: 3, side: .left)]))
        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [session(movement.variation, reps: 3, side: .left), session(movement.variation, reps: 3, side: .right)]))
    }

    func testOwnerWithNoRequirementsIsNotMastered() {
        XCTAssertFalse(ProgressionEngine.isMastered(SkillStage(name: "Empty", orderIndex: 0), against: []))
        XCTAssertFalse(ProgressionEngine.isMastered(JourneyLevel(number: 1, name: "Legacy"), against: []))
    }

    func testOrderedStateIsDerivedFromEvidenceNotStoredFlags() {
        let skill = Skill(name: "Skill", emoji: "")
        let first = SkillStage(name: "First", orderIndex: 0, isCurrent: true, isCompleted: false, skill: skill)
        let second = SkillStage(name: "Second", orderIndex: 1, isCurrent: false, isCompleted: true, skill: skill)
        let third = SkillStage(name: "Third", orderIndex: 2, isCurrent: true, isCompleted: true, skill: skill)
        skill.stages = [third, first, second]
        let firstMovement = fixture(metric: .reps)
        let secondMovement = fixture(metric: .reps)
        let thirdMovement = fixture(metric: .reps)
        first.requirements = [requirement(firstMovement.variation, target: 5, stage: first)]
        second.requirements = [requirement(secondMovement.variation, target: 5, stage: second)]
        third.requirements = [requirement(thirdMovement.variation, target: 5, stage: third)]

        let states = ProgressionEngine.orderedStageStates(
            for: skill,
            against: [session(firstMovement.variation, reps: 5), session(thirdMovement.variation, reps: 5)]
        )

        XCTAssertEqual(states, [
            SkillStageProgress(stageID: first.id, state: .completed),
            SkillStageProgress(stageID: second.id, state: .current),
            SkillStageProgress(stageID: third.id, state: .futureLocked)
        ])
    }

    func testOneDemonstrationCompletesStageEvenWithLegacyConfirmationCount() {
        let skill = Skill(name: "Skill", emoji: "")
        let stage = SkillStage(name: "Stage", orderIndex: 0, skill: skill)
        skill.stages = [stage]
        let movement = fixture(metric: .reps)
        stage.requirements = [requirement(movement.variation, target: 10, confirmationsNeeded: 20, stage: stage)]

        XCTAssertEqual(
            ProgressionEngine.orderedStageStates(for: skill, against: [session(movement.variation, reps: 10)]).first?.state,
            .completed
        )
    }

    func testExplicitImplicationCanCompleteEarlierStageWithoutStageOrderInference() {
        let skill = Skill(name: "Skill", emoji: "")
        let earlier = SkillStage(name: "Earlier", orderIndex: 0, skill: skill)
        let later = SkillStage(name: "Later", orderIndex: 1, skill: skill)
        skill.stages = [earlier, later]
        let earlierMovement = fixture(metric: .reps)
        let laterMovement = fixture(metric: .reps)
        let low = requirement(earlierMovement.variation, target: 5, stage: earlier)
        let high = requirement(laterMovement.variation, target: 10, stage: later)
        earlier.requirements = [low]
        later.requirements = [high]
        let history = [session(laterMovement.variation, reps: 10)]

        XCTAssertEqual(
            ProgressionEngine.orderedStageStates(for: skill, against: history).map(\.state),
            [.current, .futureLocked]
        )
        let implication = RequirementImplication(source: high, implies: low)
        XCTAssertEqual(
            ProgressionEngine.orderedStageStates(for: skill, against: history, implications: [implication]).map(\.state),
            [.completed, .completed]
        )
    }

    func testReevaluationAfterEvidenceRemovalChangesDerivedStageState() {
        let skill = Skill(name: "Skill", emoji: "")
        let stage = SkillStage(name: "Stage", orderIndex: 0, isCompleted: true, skill: skill)
        skill.stages = [stage]
        let movement = fixture(metric: .seconds)
        stage.requirements = [requirement(movement.variation, seconds: 10, stage: stage)]
        let proof = session(movement.variation, seconds: 10)
        let weak = session(movement.variation, seconds: 4)

        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [proof, weak]))
        XCTAssertFalse(ProgressionEngine.isMastered(stage, against: [weak]))
    }

    func testJourneyLevelUsesSameGenericDerivedLogicForCompatibility() {
        let level = JourneyLevel(number: 1, name: "Legacy")
        let stage = SkillStage(name: "Stage", orderIndex: 0)
        let movement = fixture(metric: .reps)
        let levelRequirement = Requirement(title: "Level", exerciseID: movement.exercise.id, variationID: movement.variation.id, metric: .reps, evidenceKind: .reps, targetReps: 5, journeyLevel: level)
        let stageRequirement = requirement(movement.variation, target: 5, stage: stage)
        level.genericRequirements = [levelRequirement]
        stage.requirements = [stageRequirement]
        let history = [session(movement.variation, reps: 5, completed: false)]

        XCTAssertTrue(ProgressionEngine.isMastered(level, against: history))
        XCTAssertEqual(ProgressionEngine.isMastered(level, against: history), ProgressionEngine.isMastered(stage, against: history))
    }

    private func fixture(metric: ExerciseMetric) -> (exercise: Exercise, variation: ExerciseVariation) {
        let exercise = Exercise(name: UUID().uuidString, metric: metric)
        return (exercise, ExerciseVariation(name: "Exact", metric: metric, exercise: exercise))
    }

    private func requirement(
        _ variation: ExerciseVariation,
        target: Int? = nil,
        seconds: Int? = nil,
        side: PerformanceSide = .notApplicable,
        confirmationsNeeded: Int = 2,
        stage: SkillStage
    ) -> Requirement {
        let kind: RequirementEvidenceKind = seconds == nil ? .reps : .seconds
        return Requirement(title: "Requirement", exerciseID: variation.exercise?.id, variationID: variation.id, metric: seconds == nil ? .reps : .seconds, evidenceKind: kind, side: side, targetReps: target, targetSeconds: seconds, confirmationsNeeded: confirmationsNeeded, skillStage: stage)
    }

    private func session(
        _ variation: ExerciseVariation,
        reps: Int? = nil,
        seconds: Int? = nil,
        side: PerformanceSide = .notApplicable,
        completed: Bool = true
    ) -> WorkoutSession {
        let workout = WorkoutSession(workoutName: "Workout")
        if completed { workout.completedAt = .now }
        let log = ExerciseLog(exercise: variation.exercise!, variation: variation, orderIndex: 0, session: workout)
        let set = SetLog(setNumber: 1, reps: reps, seconds: seconds, side: side, variation: variation, exerciseLog: log)
        log.sets = [set]
        workout.exerciseLogs = [log]
        return workout
    }
}
