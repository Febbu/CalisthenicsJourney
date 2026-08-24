import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class EvidenceFoundationTests: XCTestCase {
    func testFreshExercisesReceiveOneStableDefaultVariation() throws {
        let container = try makeContainer()
        let context = container.mainContext

        SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let firstIDs = Dictionary(uniqueKeysWithValues: exercises.map { exercise in
            (exercise.id, exercise.variations.filter(\.isLegacyDefault).map(\.id))
        })

        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()

        XCTAssertFalse(exercises.isEmpty)
        for exercise in exercises {
            let defaults = exercise.variations.filter(\.isLegacyDefault)
            XCTAssertEqual(defaults.count, 1)
            XCTAssertEqual(defaults.map(\.id), firstIDs[exercise.id])
            XCTAssertEqual(defaults[0].exercise?.id, exercise.id)
        }
    }

    func testLegacyHistoryMigratesToOneStableDefaultVariationWithoutInventingEvidence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Legacy movement", metric: .reps)
        let session = WorkoutSession(workoutName: "Legacy workout")
        let log = ExerciseLog(exercise: exercise, orderIndex: 0, session: session)
        let performed = SetLog(setNumber: 1, reps: 7, exerciseLog: log)
        let empty = SetLog(setNumber: 2, exerciseLog: log)
        context.insert(exercise)
        context.insert(session)
        context.insert(log)
        context.insert(performed)
        context.insert(empty)
        session.exerciseLogs = [log]
        log.sets = [performed, empty]
        try context.save()

        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()
        let firstVariationID = try XCTUnwrap(log.variationID)
        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()

        let variations = try context.fetch(FetchDescriptor<ExerciseVariation>())
        XCTAssertEqual(variations.count, 1)
        XCTAssertEqual(variations[0].id, firstVariationID)
        XCTAssertTrue(variations[0].isLegacyDefault)
        XCTAssertEqual(variations[0].name, "Legacy movement")
        XCTAssertEqual(performed.variationID, firstVariationID)
        XCTAssertEqual(empty.variationID, firstVariationID)
        XCTAssertEqual(performed.side, .notApplicable)
        XCTAssertNil(performed.attemptOutcome)
        XCTAssertNil(performed.targetWeight)
        XCTAssertNil(performed.targetMinReps)
        XCTAssertNil(performed.targetMaxReps)
        XCTAssertNil(performed.targetSeconds)
        XCTAssertTrue(performed.hasActualPerformanceEvidence)
        XCTAssertFalse(empty.hasActualPerformanceEvidence)
    }

    func testRenamingLiveContentDoesNotChangeHistoricalVariationIdentityOrSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Movement", metric: .seconds)
        let variation = ExerciseVariation(name: "Exact variation", metric: .seconds, exercise: exercise)
        let session = WorkoutSession(workoutName: "Workout")
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, seconds: 12, variation: variation, exerciseLog: log)
        context.insert(exercise)
        context.insert(variation)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        session.exerciseLogs = [log]
        log.sets = [set]
        try context.save()
        let historicalVariationID = variation.id

        exercise.name = "Renamed movement"
        variation.name = "Renamed variation"
        try context.save()

        XCTAssertEqual(log.exerciseName, "Movement")
        XCTAssertEqual(log.variationID, historicalVariationID)
        XCTAssertEqual(log.variationName, "Exact variation")
        XCTAssertEqual(set.variationID, historicalVariationID)
        XCTAssertEqual(set.variationName, "Exact variation")
    }

    func testTargetAndActualRemainIndependent() {
        let set = SetLog(
            setNumber: 1,
            reps: 3,
            targetMinReps: 5,
            targetMaxReps: 5
        )

        set.reps = 4

        XCTAssertEqual(set.reps, 4)
        XCTAssertEqual(set.targetMinReps, 5)
        XCTAssertEqual(set.targetMaxReps, 5)
        XCTAssertEqual(
            set.targetSnapshot,
            NumericTargetSnapshot(weight: nil, minReps: 5, maxReps: 5, seconds: nil)
        )
        XCTAssertEqual(
            set.actualSnapshot,
            ActualPerformanceSnapshot(weight: nil, reps: 4, seconds: nil, attemptOutcome: nil)
        )
    }

    func testSidesAreGenericAndDistinct() {
        let left = SetLog(setNumber: 1, reps: 3, side: .left)
        let right = SetLog(setNumber: 2, reps: 3, side: .right)

        XCTAssertEqual(left.side, .left)
        XCTAssertEqual(right.side, .right)
        XCTAssertNotEqual(left.side, right.side)
    }

    func testAttemptOutcomesPersistAsHistoricalEvidenceWhileEmptyRowIsNot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Technique family", metric: .reps)
        let variation = ExerciseVariation(name: "Technique variation", metric: .reps, exercise: exercise)
        let session = WorkoutSession(workoutName: "Technique")
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let successful = SetLog(
            setNumber: 1,
            effortKind: .attempt,
            attemptOutcome: .successful,
            variation: variation,
            exerciseLog: log
        )
        let unsuccessful = SetLog(
            setNumber: 2,
            effortKind: .attempt,
            attemptOutcome: .unsuccessful,
            variation: variation,
            exerciseLog: log
        )
        let empty = SetLog(
            setNumber: 3,
            effortKind: .attempt,
            variation: variation,
            exerciseLog: log
        )
        context.insert(exercise)
        context.insert(variation)
        context.insert(session)
        context.insert(log)
        context.insert(successful)
        context.insert(unsuccessful)
        context.insert(empty)
        session.exerciseLogs = [log]
        log.sets = [successful, unsuccessful, empty]
        try context.save()

        let persisted = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseLog>()).first)
            .sets.sorted { $0.setNumber < $1.setNumber }

        XCTAssertEqual(persisted[0].attemptOutcome, .successful)
        XCTAssertEqual(persisted[1].attemptOutcome, .unsuccessful)
        XCTAssertTrue(persisted[0].hasActualPerformanceEvidence)
        XCTAssertTrue(persisted[1].hasActualPerformanceEvidence)
        XCTAssertFalse(persisted[2].hasActualPerformanceEvidence)
        XCTAssertTrue(persisted.allSatisfy(\.isAttempt))
    }

    func testExistingNumericMetricsAndRelationshipsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repsExercise = Exercise(name: "Reps family", metric: .reps)
        let repsVariation = ExerciseVariation(name: "Reps variation", metric: .reps, exercise: repsExercise)
        let session = WorkoutSession(workoutName: "Metrics")
        let repsLog = ExerciseLog(exercise: repsExercise, variation: repsVariation, orderIndex: 0, session: session)
        let repsSet = SetLog(setNumber: 1, reps: 8, variation: repsVariation, exerciseLog: repsLog)
        let secondsSet = SetLog(setNumber: 2, seconds: 15, variation: repsVariation, exerciseLog: repsLog)
        let weightedSet = SetLog(setNumber: 3, weight: 25, reps: 6, variation: repsVariation, exerciseLog: repsLog)
        context.insert(repsExercise)
        context.insert(repsVariation)
        context.insert(session)
        context.insert(repsLog)
        context.insert(repsSet)
        context.insert(secondsSet)
        context.insert(weightedSet)
        session.exerciseLogs = [repsLog]
        repsLog.sets = [repsSet, secondsSet, weightedSet]
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)
        let sets = try XCTUnwrap(fetched.exerciseLogs.first).sets.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertEqual(sets[1].seconds, 15)
        XCTAssertEqual(sets[2].weight, 25)
        XCTAssertEqual(sets[2].reps, 6)
        XCTAssertEqual(sets.map(\.variationID), Array(repeating: repsVariation.id, count: 3))
        XCTAssertEqual(repsVariation.exercise?.id, repsExercise.id)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            ExerciseVariation.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            WorkoutSession.self,
            ExerciseLog.self,
            SetLog.self,
            JourneyLevel.self,
            LevelRequirement.self,
            Requirement.self,
            Skill.self,
            SkillStage.self,
            configurations: configuration
        )
    }
}
