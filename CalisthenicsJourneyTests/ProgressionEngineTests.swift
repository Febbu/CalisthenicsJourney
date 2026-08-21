import XCTest
@testable import CalisthenicsJourney

@MainActor
final class ProgressionEngineTests: XCTestCase {
    func testStageIsNotMasteredWhenOneRequirementIsMissing() {
        let stage = makeStage()
        let repsExercise = Exercise(name: "Reps", metric: .reps)
        let holdExercise = Exercise(name: "Hold", metric: .seconds)
        stage.requirements = [
            requirement(exercise: repsExercise, targetReps: 10, stage: stage),
            requirement(exercise: holdExercise, targetSeconds: 20, stage: stage)
        ]

        XCTAssertFalse(
            ProgressionEngine.isMastered(
                stage,
                against: [session(exercise: repsExercise, reps: 10)]
            )
        )
    }

    func testStageIsMasteredWhenAllRequirementsPass() {
        let stage = makeStage()
        let repsExercise = Exercise(name: "Reps", metric: .reps)
        let holdExercise = Exercise(name: "Hold", metric: .seconds)
        stage.requirements = [
            requirement(exercise: repsExercise, targetReps: 10, stage: stage),
            requirement(exercise: holdExercise, targetSeconds: 20, stage: stage)
        ]

        let sessions = [
            session(exercise: repsExercise, reps: 10),
            session(exercise: holdExercise, seconds: 20)
        ]

        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: sessions))
    }

    func testOwnerWithNoRequirementsIsNotMastered() {
        XCTAssertFalse(ProgressionEngine.isMastered(makeStage(), against: []))

        let level = JourneyLevel(number: 1, name: "Empty Level")
        XCTAssertFalse(ProgressionEngine.isMastered(level, against: []))
    }

    func testOrderedStagesProduceCompletedCurrentAndFutureStates() {
        let skill = Skill(name: "Editable skill", emoji: "")
        let first = makeStage(name: "First", orderIndex: 0, skill: skill)
        let second = makeStage(name: "Second", orderIndex: 1, skill: skill)
        let third = makeStage(name: "Third", orderIndex: 2, skill: skill)
        skill.stages = [third, first, second]

        let firstExercise = Exercise(name: "First exercise", metric: .reps)
        let secondExercise = Exercise(name: "Second exercise", metric: .reps)
        let thirdExercise = Exercise(name: "Third exercise", metric: .reps)
        first.requirements = [requirement(exercise: firstExercise, targetReps: 5, stage: first)]
        second.requirements = [requirement(exercise: secondExercise, targetReps: 5, stage: second)]
        third.requirements = [requirement(exercise: thirdExercise, targetReps: 5, stage: third)]

        let states = ProgressionEngine.orderedStageStates(
            for: skill,
            against: [
                session(exercise: firstExercise, reps: 5),
                session(exercise: thirdExercise, reps: 5)
            ]
        )

        XCTAssertEqual(
            states,
            [
                SkillStageProgress(stageID: first.id, state: .completed),
                SkillStageProgress(stageID: second.id, state: .current),
                SkillStageProgress(stageID: third.id, state: .futureLocked)
            ]
        )
    }

    func testProgressChangesWhenLaterQualifyingSessionIsAdded() {
        let skill = Skill(name: "Editable skill", emoji: "")
        let stage = makeStage(skill: skill)
        skill.stages = [stage]
        let exercise = Exercise(name: "Movement", metric: .reps)
        stage.requirements = [
            requirement(
                exercise: exercise,
                targetReps: 10,
                confirmationsNeeded: 2,
                stage: stage
            )
        ]
        let firstSession = session(exercise: exercise, reps: 10)

        XCTAssertEqual(
            ProgressionEngine.orderedStageStates(for: skill, against: [firstSession]).first?.state,
            .current
        )

        let laterSession = session(exercise: exercise, reps: 11)
        XCTAssertEqual(
            ProgressionEngine.orderedStageStates(
                for: skill,
                against: [firstSession, laterSession]
            ).first?.state,
            .completed
        )
    }

    func testExerciseRenamingHasNoEffectOnProgression() {
        let stage = makeStage()
        let exercise = Exercise(name: "Original name", metric: .reps)
        stage.requirements = [requirement(exercise: exercise, targetReps: 10, stage: stage)]
        let workout = session(exercise: exercise, reps: 10)

        exercise.name = "Renamed movement"

        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [workout]))
    }

    func testUnfinishedSessionWithRealResultCounts() {
        let stage = makeStage()
        let exercise = Exercise(name: "Movement", metric: .seconds)
        stage.requirements = [requirement(exercise: exercise, targetSeconds: 20, stage: stage)]
        let unfinishedSession = session(exercise: exercise, seconds: 20, isCompleted: false)

        XCTAssertNil(unfinishedSession.completedAt)
        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [unfinishedSession]))
    }

    func testJourneyLevelUsesSameGenericMasteryLogicAsSkillStage() {
        let level = JourneyLevel(number: 2, name: "Editable level")
        let stage = makeStage()
        let exercise = Exercise(name: "Movement", metric: .reps)
        let levelRequirement = Requirement(
            title: "Level target",
            exerciseID: exercise.id,
            metric: .reps,
            targetReps: 10,
            confirmationsNeeded: 1,
            journeyLevel: level
        )
        let stageRequirement = requirement(exercise: exercise, targetReps: 10, stage: stage)
        level.genericRequirements = [levelRequirement]
        stage.requirements = [stageRequirement]
        let sessions = [session(exercise: exercise, reps: 10)]

        XCTAssertEqual(
            ProgressionEngine.isMastered(level, against: sessions),
            ProgressionEngine.isMastered(stage, against: sessions)
        )
        XCTAssertTrue(ProgressionEngine.isMastered(level, against: sessions))
    }

    private func makeStage(
        name: String = "Stage",
        orderIndex: Int = 0,
        skill: Skill? = nil
    ) -> SkillStage {
        SkillStage(name: name, orderIndex: orderIndex, skill: skill)
    }

    private func requirement(
        exercise: Exercise,
        targetReps: Int? = nil,
        targetSeconds: Int? = nil,
        confirmationsNeeded: Int = 1,
        stage: SkillStage
    ) -> Requirement {
        Requirement(
            title: "Editable requirement",
            exerciseID: exercise.id,
            metric: targetSeconds == nil ? .reps : .seconds,
            targetReps: targetReps,
            targetSeconds: targetSeconds,
            confirmationsNeeded: confirmationsNeeded,
            skillStage: stage
        )
    }

    private func session(
        exercise: Exercise,
        reps: Int? = nil,
        seconds: Int? = nil,
        isCompleted: Bool = true
    ) -> WorkoutSession {
        let workout = WorkoutSession(workoutName: "Test Workout")
        if isCompleted {
            workout.completedAt = .now
        }

        let log = ExerciseLog(exercise: exercise, orderIndex: 0, session: workout)
        let set = SetLog(
            setNumber: 1,
            reps: reps,
            seconds: seconds,
            exerciseLog: log
        )
        log.sets = [set]
        workout.exerciseLogs = [log]
        return workout
    }
}
