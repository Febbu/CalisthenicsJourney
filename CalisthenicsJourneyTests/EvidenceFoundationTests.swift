import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class EvidenceFoundationTests: XCTestCase {
    func testLegacyExercisesReceiveOneStableDefaultVariationDuringCanonicalInstallation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let legacy = Exercise(name: "Legacy movement", metric: .reps)
        context.insert(legacy)
        try context.save()

        try SeedData.installIfNeeded(context: context, existingExerciseCount: 1)
        let firstIDs = legacy.variations.filter(\.isLegacyDefault).map(\.id)

        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()

        let defaults = legacy.variations.filter(\.isLegacyDefault)
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.map(\.id), firstIDs)
        XCTAssertEqual(defaults[0].exercise?.id, legacy.id)
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
        XCTAssertEqual(performed.evidenceMetric, .reps)
        XCTAssertEqual(performed.side, .notApplicable)
        XCTAssertNil(performed.attemptOutcome)
        XCTAssertNil(performed.targetWeight)
        XCTAssertNil(performed.targetMinReps)
        XCTAssertNil(performed.targetMaxReps)
        XCTAssertNil(performed.targetSeconds)
        XCTAssertTrue(performed.hasActualPerformanceEvidence)
        XCTAssertFalse(empty.hasActualPerformanceEvidence)
    }

    func testRenamingOrChangingLiveContentDoesNotChangeHistoricalEvidence() throws {
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
        variation.metric = .reps
        try context.save()

        XCTAssertEqual(log.exerciseName, "Movement")
        XCTAssertEqual(log.variationID, historicalVariationID)
        XCTAssertEqual(log.variationName, "Exact variation")
        XCTAssertEqual(set.variationID, historicalVariationID)
        XCTAssertEqual(set.variationName, "Exact variation")
        XCTAssertEqual(set.evidenceMetric, .seconds)
    }

    func testTargetsSidesAndActualsPersistIndependently() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Weighted family", metric: .weightAndReps)
        let variation = ExerciseVariation(name: "Weighted variation", metric: .weightAndReps, exercise: exercise)
        let session = WorkoutSession(workoutName: "Targets")
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(
            setNumber: 1,
            weight: 20,
            reps: 3,
            targetWeight: 25,
            targetMinReps: 5,
            targetMaxReps: 8,
            targetSeconds: 30,
            side: .left,
            variation: variation,
            exerciseLog: log
        )
        let right = SetLog(
            setNumber: 2,
            weight: 20,
            reps: 3,
            side: .right,
            variation: variation,
            exerciseLog: log
        )
        let unknownTargets = SetLog(
            setNumber: 3,
            metric: .weightAndReps,
            exerciseLog: log
        )
        context.insert(exercise)
        context.insert(variation)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        context.insert(right)
        context.insert(unknownTargets)
        session.exerciseLogs = [log]
        log.sets = [set, right, unknownTargets]
        try context.save()

        set.reps = 4
        try context.save()

        let persisted = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseLog>()).first)
            .sets.sorted { $0.setNumber < $1.setNumber }

        XCTAssertEqual(persisted[0].reps, 4)
        XCTAssertEqual(persisted[0].side, .left)
        XCTAssertEqual(persisted[1].side, .right)
        XCTAssertEqual(
            persisted[0].targetSnapshot,
            NumericTargetSnapshot(weight: 25, minReps: 5, maxReps: 8, seconds: 30)
        )
        XCTAssertEqual(
            persisted[0].actualSnapshot,
            ActualPerformanceSnapshot(weight: 20, reps: 4, seconds: nil, attemptOutcome: nil)
        )
        XCTAssertEqual(persisted[2].side, .notApplicable)
        XCTAssertEqual(
            persisted[2].targetSnapshot,
            NumericTargetSnapshot(weight: nil, minReps: nil, maxReps: nil, seconds: nil)
        )
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
        let repsExercise = Exercise(name: "Metrics family", metric: .reps)
        let repsVariation = ExerciseVariation(name: "Reps variation", metric: .reps, exercise: repsExercise)
        let secondsVariation = ExerciseVariation(name: "Seconds variation", metric: .seconds, exercise: repsExercise)
        let weightedVariation = ExerciseVariation(name: "Weighted variation", metric: .weightAndReps, exercise: repsExercise)
        let session = WorkoutSession(workoutName: "Metrics")
        let repsLog = ExerciseLog(exercise: repsExercise, variation: repsVariation, orderIndex: 0, session: session)
        let repsSet = SetLog(setNumber: 1, reps: 8, variation: repsVariation, exerciseLog: repsLog)
        let secondsSet = SetLog(setNumber: 2, seconds: 15, variation: secondsVariation, exerciseLog: repsLog)
        let weightedSet = SetLog(setNumber: 3, weight: 25, reps: 6, variation: weightedVariation, exerciseLog: repsLog)
        context.insert(repsExercise)
        context.insert(repsVariation)
        context.insert(secondsVariation)
        context.insert(weightedVariation)
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
        XCTAssertEqual(sets.map(\.variationID), [repsVariation.id, secondsVariation.id, weightedVariation.id])
        XCTAssertEqual(sets.map(\.evidenceMetric), [.reps, .seconds, .weightAndReps])
        XCTAssertEqual(repsVariation.exercise?.id, repsExercise.id)
    }

    func testEvidencePresenceUsesEffortKindAndHistoricalMetric() {
        XCTAssertTrue(SetLog(setNumber: 1, reps: 1, metric: .reps).hasActualPerformanceEvidence)
        XCTAssertFalse(SetLog(setNumber: 1, metric: .reps).hasActualPerformanceEvidence)
        XCTAssertFalse(SetLog(setNumber: 1, seconds: 5, metric: .reps).hasActualPerformanceEvidence)

        XCTAssertTrue(SetLog(setNumber: 1, seconds: 5, metric: .seconds).hasActualPerformanceEvidence)
        XCTAssertFalse(SetLog(setNumber: 1, metric: .seconds).hasActualPerformanceEvidence)
        XCTAssertFalse(SetLog(setNumber: 1, reps: 5, metric: .seconds).hasActualPerformanceEvidence)

        XCTAssertTrue(
            SetLog(setNumber: 1, weight: 20, reps: 5, metric: .weightAndReps)
                .hasActualPerformanceEvidence
        )
        XCTAssertFalse(
            SetLog(setNumber: 1, weight: 20, metric: .weightAndReps)
                .hasActualPerformanceEvidence
        )
        XCTAssertFalse(
            SetLog(setNumber: 1, reps: 5, metric: .weightAndReps)
                .hasActualPerformanceEvidence
        )

        XCTAssertFalse(
            SetLog(setNumber: 1, reps: 5, effortKind: .attempt)
                .hasActualPerformanceEvidence
        )
        XCTAssertFalse(
            SetLog(setNumber: 1, metric: .seconds, attemptOutcome: .successful)
                .hasActualPerformanceEvidence
        )
    }

    func testDeletingVariationPreservesHistoricalSnapshotsAndInterpretation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Family", metric: .seconds)
        let variation = ExerciseVariation(name: "Historical hold", metric: .seconds, exercise: exercise)
        let session = WorkoutSession(workoutName: "Deletion")
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
        let variationID = variation.id

        context.delete(variation)
        try context.save()

        let verificationContext = ModelContext(container)
        XCTAssertTrue(try verificationContext.fetch(FetchDescriptor<ExerciseVariation>()).isEmpty)
        let persistedSets = try verificationContext.fetch(FetchDescriptor<SetLog>())
        let persistedSet = try XCTUnwrap(persistedSets.first { $0.id == set.id })
        XCTAssertEqual(persistedSet.variationID, variationID)
        XCTAssertEqual(persistedSet.variationName, "Historical hold")
        XCTAssertEqual(persistedSet.evidenceMetric, .seconds)
        XCTAssertTrue(persistedSet.hasActualPerformanceEvidence)
    }

    func testDeletingExercisePreservesHistoricalEvidenceSnapshots() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Family", metric: .reps)
        let variation = ExerciseVariation(name: "Exact movement", metric: .reps, exercise: exercise)
        let session = WorkoutSession(workoutName: "Deletion")
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, reps: 5, variation: variation, exerciseLog: log)
        context.insert(exercise)
        context.insert(variation)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        session.exerciseLogs = [log]
        log.sets = [set]
        try context.save()
        let exerciseID = exercise.id
        let variationID = variation.id

        context.delete(exercise)
        try context.save()

        XCTAssertEqual(log.exerciseID, exerciseID)
        XCTAssertEqual(log.exerciseName, "Family")
        XCTAssertEqual(set.variationID, variationID)
        XCTAssertEqual(set.variationName, "Exact movement")
        XCTAssertEqual(set.evidenceMetric, .reps)
        XCTAssertTrue(set.hasActualPerformanceEvidence)
    }

    func testMigrationPreservesHistoricalNameAfterLiveExerciseRename() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Original name", metric: .reps)
        let session = WorkoutSession(workoutName: "History")
        let log = ExerciseLog(exercise: exercise, orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, reps: 4, exerciseLog: log)
        context.insert(exercise)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        session.exerciseLogs = [log]
        log.sets = [set]
        try context.save()
        exercise.name = "Current name"
        try context.save()

        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()

        XCTAssertEqual(log.exerciseName, "Original name")
        XCTAssertEqual(log.variationName, "Original name")
        XCTAssertEqual(set.variationName, "Original name")
        XCTAssertEqual(log.variation?.name, "Current name")
    }

    func testMigrationRecoversSharedOrphanIdentityWithoutDuplicateDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let removedExercise = Exercise(name: "Historical movement", metric: .seconds)
        let sharedID = removedExercise.id
        let firstSession = WorkoutSession(workoutName: "First")
        let secondSession = WorkoutSession(workoutName: "Second")
        let firstLog = ExerciseLog(exercise: removedExercise, orderIndex: 0, session: firstSession)
        let secondLog = ExerciseLog(exercise: removedExercise, orderIndex: 0, session: secondSession)
        let firstSet = SetLog(setNumber: 1, seconds: 8, exerciseLog: firstLog)
        let secondSet = SetLog(setNumber: 1, seconds: 10, exerciseLog: secondLog)
        context.insert(firstSession)
        context.insert(secondSession)
        context.insert(firstLog)
        context.insert(secondLog)
        context.insert(firstSet)
        context.insert(secondSet)
        firstSession.exerciseLogs = [firstLog]
        secondSession.exerciseLogs = [secondLog]
        firstLog.sets = [firstSet]
        secondLog.sets = [secondSet]
        try context.save()

        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()
        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try context.save()

        let recovered = try context.fetch(FetchDescriptor<Exercise>()).filter { $0.id == sharedID }
        let defaults = try context.fetch(FetchDescriptor<ExerciseVariation>()).filter {
            $0.exercise?.id == sharedID && $0.isLegacyDefault
        }
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(firstLog.variationID, defaults[0].id)
        XCTAssertEqual(secondLog.variationID, defaults[0].id)
        XCTAssertEqual(firstSet.evidenceMetric, .seconds)
        XCTAssertEqual(secondSet.evidenceMetric, .seconds)
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
            RequirementImplication.self,
            Skill.self,
            SkillStage.self,
            EquipmentDefinition.self,
            AthleteProfile.self,
            EquipmentAvailability.self,
            SkillGoal.self,
            SkillStageConnection.self,
            SkillExerciseLink.self,
            VariationEquipmentMapping.self,
            VariationEquipmentSetup.self,
            VariationEquipmentItem.self,
            configurations: configuration
        )
    }
}
