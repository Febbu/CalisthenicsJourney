import XCTest
@testable import CalisthenicsJourney

@MainActor
final class RequirementEvaluatorTests: XCTestCase {
    func testRepsThresholdUsesActualLoggedValue() {
        let exercise = Exercise(name: "Editable name", metric: .reps)
        let requirement = makeRequirement(exercise: exercise, metric: .reps, targetReps: 20)
        let sessions = [19, 20, 21].map { session(exercise: exercise, reps: $0) }

        let evaluation = RequirementEvaluator.evaluate(requirement, against: sessions)

        XCTAssertEqual(evaluation.qualifyingSessionCount, 2)
        XCTAssertTrue(evaluation.isMastered)
    }

    func testSecondsThresholdUsesActualLoggedValue() {
        let exercise = Exercise(name: "Timed hold", metric: .seconds)
        let requirement = makeRequirement(exercise: exercise, metric: .seconds, targetSeconds: 30)
        let sessions = [29, 30].map { session(exercise: exercise, seconds: $0) }

        let evaluation = RequirementEvaluator.evaluate(requirement, against: sessions)

        XCTAssertEqual(evaluation.qualifyingSessionCount, 1)
        XCTAssertFalse(evaluation.isMastered)
    }

    func testWeightAndRepsMustBothReachTheirTargets() {
        let exercise = Exercise(name: "Weighted movement", metric: .weightAndReps)
        let requirement = makeRequirement(
            exercise: exercise,
            metric: .weightAndReps,
            targetReps: 10,
            targetWeight: 100
        )
        let sessions = [
            session(exercise: exercise, weight: 99, reps: 10),
            session(exercise: exercise, weight: 100, reps: 9),
            session(exercise: exercise, weight: 100, reps: 10)
        ]

        let evaluation = RequirementEvaluator.evaluate(requirement, against: sessions)

        XCTAssertEqual(evaluation.qualifyingSessionCount, 1)
    }

    func testEmptyPlannedSetDoesNotCount() {
        let exercise = Exercise(name: "Movement", metric: .reps)
        let requirement = makeRequirement(exercise: exercise, metric: .reps, targetReps: 1)

        let evaluation = RequirementEvaluator.evaluate(
            requirement,
            against: [session(exercise: exercise)]
        )

        XCTAssertEqual(evaluation.qualifyingSessionCount, 0)
    }

    func testQualifyingSetInUnfinishedWorkoutCounts() {
        let exercise = Exercise(name: "Movement", metric: .reps)
        let requirement = makeRequirement(exercise: exercise, metric: .reps, targetReps: 10)
        let unfinishedSession = session(exercise: exercise, reps: 10, isCompleted: false)

        let evaluation = RequirementEvaluator.evaluate(
            requirement,
            against: [unfinishedSession]
        )

        XCTAssertNil(unfinishedSession.completedAt)
        XCTAssertEqual(evaluation.qualifyingSessionCount, 1)
    }

    func testMultipleQualifyingSetsInOneSessionCountOnce() {
        let exercise = Exercise(name: "Movement", metric: .reps)
        let requirement = makeRequirement(exercise: exercise, metric: .reps, targetReps: 10)
        let workout = session(exercise: exercise, reps: 10)
        let log = workout.exerciseLogs[0]
        log.sets.append(SetLog(setNumber: 2, reps: 12, exerciseLog: log))

        let evaluation = RequirementEvaluator.evaluate(requirement, against: [workout])

        XCTAssertEqual(evaluation.qualifyingSessionCount, 1)
    }

    func testSeparateSessionsCountAndVisibleConfirmationIsCapped() {
        let exercise = Exercise(name: "Movement", metric: .reps)
        let requirement = makeRequirement(exercise: exercise, metric: .reps, targetReps: 10)
        let sessions = (1...3).map { _ in session(exercise: exercise, reps: 10) }

        let evaluation = RequirementEvaluator.evaluate(requirement, against: sessions)

        XCTAssertEqual(evaluation.qualifyingSessionCount, 3)
        XCTAssertEqual(evaluation.confirmedCount, 2)
        XCTAssertTrue(evaluation.isMastered)
    }

    func testDifferentExerciseIdentityDoesNotCount() {
        let requiredExercise = Exercise(name: "Same display name", metric: .reps)
        let otherExercise = Exercise(name: "Same display name", metric: .reps)
        let requirement = makeRequirement(
            exercise: requiredExercise,
            metric: .reps,
            targetReps: 10
        )

        let evaluation = RequirementEvaluator.evaluate(
            requirement,
            against: [session(exercise: otherExercise, reps: 20)]
        )

        XCTAssertEqual(evaluation.qualifyingSessionCount, 0)
    }

    private func makeRequirement(
        exercise: Exercise,
        metric: RequirementMetric,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil
    ) -> LevelRequirement {
        LevelRequirement(
            title: "Editable requirement",
            exerciseID: exercise.id,
            metric: metric,
            targetReps: targetReps,
            targetWeight: targetWeight,
            targetSeconds: targetSeconds,
            confirmationsNeeded: 2
        )
    }

    private func session(
        exercise: Exercise,
        weight: Double? = nil,
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
            weight: weight,
            reps: reps,
            seconds: seconds,
            exerciseLog: log
        )
        log.sets = [set]
        workout.exerciseLogs = [log]
        return workout
    }
}
