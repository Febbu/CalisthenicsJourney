import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class PrescriptionStateTests: XCTestCase {
    func testOneStatePerAthleteAndExactVariationAcrossSharedSkillLinks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstAthlete = AthleteProfile()
        let secondAthlete = AthleteProfile()
        let exercise = Exercise(name: "Pulling family", metric: .reps)
        let strictPullUp = ExerciseVariation(name: "Strict Pull-up", metric: .reps, exercise: exercise)
        context.insert(firstAthlete)
        context.insert(secondAthlete)
        context.insert(exercise)
        context.insert(strictPullUp)

        for name in ["Pull-up", "Muscle-up", "Front Lever"] {
            let skill = Skill(name: name, emoji: "")
            let stage = SkillStage(name: "Shared work", orderIndex: 0, skill: skill)
            context.insert(skill)
            context.insert(stage)
            context.insert(SkillExerciseLink(skill: skill, stage: stage, variation: strictPullUp, role: .direct))
            _ = try PrescriptionStateService.storeEstimate(
                athleteID: firstAthlete.id,
                variationID: strictPullUp.id,
                mode: .reps,
                values: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
                context: context
            )
            try context.save()
        }

        _ = try PrescriptionStateService.storeExploratory(
            athleteID: secondAthlete.id,
            variationID: strictPullUp.id,
            mode: .reps,
            context: context
        )
        try context.save()

        let states = try context.fetch(FetchDescriptor<ExercisePrescriptionState>())
        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states.filter { $0.athleteID == firstAthlete.id }.count, 1)
        XCTAssertEqual(states.filter { $0.athleteID == secondAthlete.id }.count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SkillExerciseLink>()), 3)
    }

    func testRepAndHoldEstimatesPersistWithoutCreatingEvidenceOrMastery() throws {
        let storeURL = temporaryStoreURL()
        defer { removeStore(at: storeURL) }
        let athleteID = UUID()
        let repsVariationID = UUID()
        let holdVariationID = UUID()

        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let athlete = AthleteProfile(id: athleteID)
            let exercise = Exercise(name: "Movement", metric: .reps)
            let repsVariation = ExerciseVariation(name: "Exact", metric: .reps, exercise: exercise)
            repsVariation.id = repsVariationID
            let holdVariation = ExerciseVariation(name: "Exact", metric: .seconds, exercise: exercise)
            holdVariation.id = holdVariationID
            let skill = Skill(name: "Skill", emoji: "")
            let stage = SkillStage(name: "Stage", orderIndex: 0, skill: skill)
            let requirement = Requirement(
                title: "Five reps",
                variationID: repsVariation.id,
                metric: .reps,
                targetReps: 5,
                confirmationsNeeded: 1,
                skillStage: stage
            )
            context.insert(athlete)
            context.insert(exercise)
            context.insert(repsVariation)
            context.insert(holdVariation)
            context.insert(skill)
            context.insert(stage)
            context.insert(requirement)

            _ = try PrescriptionStateService.storeEstimate(
                athleteID: athlete.id,
                variationID: repsVariation.id,
                mode: .reps,
                values: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
                context: context
            )
            _ = try PrescriptionStateService.storeEstimate(
                athleteID: athlete.id,
                variationID: holdVariation.id,
                mode: .duration,
                values: ThreeWorkingSetValues(first: 12, second: 10, third: 8),
                context: context
            )
            try context.save()

            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetLog>()), 0)
            XCTAssertFalse(RequirementEvaluator.evaluate(requirement, against: []).isSatisfied)
            XCTAssertFalse(ProgressionEngine.isMastered(stage, against: []))
        }

        do {
            let reopened = try makeContainer(at: storeURL)
            let fresh = ModelContext(reopened)
            let states = try fresh.fetch(FetchDescriptor<ExercisePrescriptionState>())
            XCTAssertEqual(states.count, 2)
            XCTAssertEqual(states.first { $0.variationID == repsVariationID }?.mode, .reps)
            XCTAssertEqual(
                states.first { $0.variationID == repsVariationID }?.workingSetValues,
                ThreeWorkingSetValues(first: 5, second: 4, third: 3)
            )
            XCTAssertEqual(states.first { $0.variationID == holdVariationID }?.mode, .duration)
            XCTAssertEqual(
                states.first { $0.variationID == holdVariationID }?.workingSetValues,
                ThreeWorkingSetValues(first: 12, second: 10, third: 8)
            )
            XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<SetLog>()), 0)
        }
    }

    func testExploratoryAndAttemptStatesHaveNoFabricatedNumericTarget() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let athlete = AthleteProfile()
        let variation = ExerciseVariation(name: "Any name", metric: .reps)
        context.insert(athlete)
        context.insert(variation)

        let repState = try PrescriptionStateService.storeExploratory(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            context: context
        )
        XCTAssertEqual(repState.basisKind, .exploratory)
        XCTAssertNil(repState.workingSetValues)

        let attemptState = try PrescriptionStateService.storeExploratory(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .attempts,
            context: context
        )
        XCTAssertEqual(attemptState.mode, .attempts)
        XCTAssertEqual(attemptState.basisKind, .exploratory)
        XCTAssertNil(attemptState.firstWorkingSetValue)
        XCTAssertNil(attemptState.secondWorkingSetValue)
        XCTAssertNil(attemptState.thirdWorkingSetValue)
    }

    func testRecentExactVariationPerformanceSupersedesEstimateByStableID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let exercise = Exercise(name: "Family", metric: .reps)
        let exact = ExerciseVariation(name: "Same display name", metric: .reps, exercise: exercise)
        let other = ExerciseVariation(name: "Same display name", metric: .reps, exercise: exercise)
        context.insert(athlete)
        context.insert(exercise)
        context.insert(exact)
        context.insert(other)

        _ = try PrescriptionStateService.storeEstimate(
            athleteID: athlete.id,
            variationID: exact.id,
            mode: .reps,
            values: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
            context: context,
            now: now.addingTimeInterval(-7 * 24 * 60 * 60)
        )
        addPerformance(
            variation: other,
            reps: [20, 20, 20],
            at: now.addingTimeInterval(-2 * 24 * 60 * 60),
            context: context
        )
        addPerformance(
            variation: exact,
            reps: [7, 6, 5],
            at: now.addingTimeInterval(-24 * 60 * 60),
            context: context
        )
        try context.save()

        let result = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: exact.id,
            mode: .reps,
            context: context,
            asOf: now
        )
        guard case let .ready(state) = result else {
            return XCTFail("Expected recent exact-variation history to initialize state")
        }
        XCTAssertEqual(state.basisKind, .realPerformance)
        XCTAssertEqual(state.workingSetValues, ThreeWorkingSetValues(first: 7, second: 6, third: 5))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetLog>()), 6)
    }

    func testEstimateCannotDowngradeAuthoritativeRealPerformance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let variation = ExerciseVariation(name: "Exact", metric: .reps)
        context.insert(athlete)
        context.insert(variation)
        addPerformance(variation: variation, reps: [7, 6, 5], at: now, context: context)
        try context.save()

        let initialized = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            context: context,
            asOf: now
        )
        guard case let .ready(anchored) = initialized else {
            return XCTFail("Expected real performance to anchor prescription state")
        }
        let anchoredUpdatedAt = anchored.updatedAt

        let result = try PrescriptionStateService.storeEstimate(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            values: ThreeWorkingSetValues(first: 3, second: 2, third: 1),
            context: context,
            now: now.addingTimeInterval(60)
        )

        XCTAssertEqual(result.id, anchored.id)
        XCTAssertEqual(result.basisKind, .realPerformance)
        XCTAssertEqual(result.workingSetValues, ThreeWorkingSetValues(first: 7, second: 6, third: 5))
        XCTAssertEqual(result.lastRelevantPerformanceAt, now)
        XCTAssertEqual(result.updatedAt, anchoredUpdatedAt)
    }

    func testExploratoryCannotDowngradeAuthoritativeRealPerformance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let variation = ExerciseVariation(name: "Exact", metric: .seconds)
        context.insert(athlete)
        context.insert(variation)
        addPerformance(variation: variation, seconds: [12, 10, 8], at: now, context: context)
        try context.save()

        let initialized = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .duration,
            context: context,
            asOf: now
        )
        guard case let .ready(anchored) = initialized else {
            return XCTFail("Expected real performance to anchor prescription state")
        }

        let result = try PrescriptionStateService.storeExploratory(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .duration,
            context: context,
            now: now.addingTimeInterval(60)
        )

        XCTAssertEqual(result.id, anchored.id)
        XCTAssertEqual(result.basisKind, .realPerformance)
        XCTAssertEqual(result.workingSetValues, ThreeWorkingSetValues(first: 12, second: 10, third: 8))
        XCTAssertEqual(result.lastRelevantPerformanceAt, now)
    }

    func testRealPerformanceWithoutTimestampRequiresCalibration() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let variation = ExerciseVariation(name: "Exact", metric: .reps)
        let malformed = ExercisePrescriptionState(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            basisKind: .realPerformance,
            workingSetValues: ThreeWorkingSetValues(first: 7, second: 6, third: 5),
            now: now
        )
        context.insert(athlete)
        context.insert(variation)
        context.insert(malformed)
        addPerformance(variation: variation, reps: [7, 6, 5], at: now, context: context)
        try context.save()

        let result = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            context: context,
            asOf: now
        )

        guard case let .calibrationRequired(existing) = result else {
            return XCTFail("Malformed real-performance state must not be ready")
        }
        XCTAssertEqual(existing?.id, malformed.id)
        XCTAssertFalse(malformed.isUsable(for: .reps))
    }

    func testOwnershipIdentityDisagreementRequiresCalibration() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let requestedAthlete = AthleteProfile()
        let otherAthlete = AthleteProfile()
        let requestedVariation = ExerciseVariation(name: "Requested", metric: .reps)
        let otherVariation = ExerciseVariation(name: "Other", metric: .reps)
        context.insert(requestedAthlete)
        context.insert(otherAthlete)
        context.insert(requestedVariation)
        context.insert(otherVariation)

        let athleteMismatch = ExercisePrescriptionState(
            athleteID: requestedAthlete.id,
            variationID: requestedVariation.id,
            mode: .reps,
            basisKind: .estimate,
            workingSetValues: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
            now: now
        )
        athleteMismatch.athleteID = otherAthlete.id
        context.insert(athleteMismatch)

        let variationMismatch = ExercisePrescriptionState(
            athleteID: requestedAthlete.id,
            variationID: otherVariation.id,
            mode: .reps,
            basisKind: .estimate,
            workingSetValues: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
            now: now
        )
        variationMismatch.variationID = requestedVariation.id
        context.insert(variationMismatch)
        try context.save()

        let athleteResult = try PrescriptionStateService.initializeIfPossible(
            athleteID: requestedAthlete.id,
            variationID: requestedVariation.id,
            mode: .reps,
            context: context,
            asOf: now
        )
        let variationResult = try PrescriptionStateService.initializeIfPossible(
            athleteID: requestedAthlete.id,
            variationID: otherVariation.id,
            mode: .reps,
            context: context,
            asOf: now
        )

        guard case let .calibrationRequired(athleteState) = athleteResult,
              case let .calibrationRequired(variationState) = variationResult else {
            return XCTFail("Ownership disagreement must not be ready")
        }
        XCTAssertEqual(athleteState?.id, athleteMismatch.id)
        XCTAssertEqual(variationState?.id, variationMismatch.id)
    }

    func testValidExistingRealPerformanceStateRemainsReady() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let variation = ExerciseVariation(name: "Exact", metric: .reps)
        let state = ExercisePrescriptionState(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            basisKind: .realPerformance,
            workingSetValues: ThreeWorkingSetValues(first: 7, second: 6, third: 5),
            lastRelevantPerformanceAt: now,
            now: now
        )
        context.insert(athlete)
        context.insert(variation)
        context.insert(state)
        try context.save()

        let result = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            context: context,
            asOf: now.addingTimeInterval(60)
        )

        guard case let .ready(existing) = result else {
            return XCTFail("Valid real-performance state should remain ready")
        }
        XCTAssertEqual(existing.id, state.id)
    }

    func testDifferentVariationHistoryDoesNotInitializeNumericCapacity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let exercise = Exercise(name: "Family", metric: .reps)
        let requested = ExerciseVariation(name: "Renamed requested", metric: .reps, exercise: exercise)
        let historical = ExerciseVariation(name: "Renamed requested", metric: .reps, exercise: exercise)
        context.insert(athlete)
        context.insert(exercise)
        context.insert(requested)
        context.insert(historical)
        addPerformance(variation: historical, reps: [9, 8, 7], at: now, context: context)
        try context.save()

        let result = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: requested.id,
            mode: .reps,
            context: context,
            asOf: now
        )
        guard case let .calibrationRequired(state) = result else {
            return XCTFail("Different stable variation identity must not initialize capacity")
        }
        XCTAssertNil(state)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExercisePrescriptionState>()), 0)
    }

    func testSixMonthStalenessRequestsRecalibrationWithoutChangingTruth() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let oldDate = now.addingTimeInterval(-PrescriptionStalenessPolicy.v1.threshold - 1)
        let athlete = AthleteProfile()
        let exercise = Exercise(name: "Family", metric: .reps)
        let variation = ExerciseVariation(name: "Exact", metric: .reps, exercise: exercise)
        let skill = Skill(name: "Mastered", emoji: "")
        let stage = SkillStage(name: "Stage", orderIndex: 0, isCompleted: true, skill: skill)
        context.insert(athlete)
        context.insert(exercise)
        context.insert(variation)
        context.insert(skill)
        context.insert(stage)
        addPerformance(variation: variation, reps: [8, 7, 6], at: oldDate, context: context)
        let state = ExercisePrescriptionState(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            basisKind: .realPerformance,
            workingSetValues: ThreeWorkingSetValues(first: 8, second: 7, third: 6),
            lastRelevantPerformanceAt: oldDate,
            now: oldDate
        )
        context.insert(state)
        try context.save()
        let setIDs = Set(try context.fetch(FetchDescriptor<SetLog>()).map(\.id))

        let result = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: variation.id,
            mode: .reps,
            context: context,
            asOf: now
        )
        guard case let .calibrationRequired(existing) = result else {
            return XCTFail("Expected stale prescription state to request recalibration")
        }
        XCTAssertEqual(existing?.id, state.id)
        XCTAssertEqual(existing?.workingSetValues, ThreeWorkingSetValues(first: 8, second: 7, third: 6))
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<SetLog>()).map(\.id)), setIDs)
        XCTAssertTrue(stage.isCompleted)
    }

    func testRecentExactHistoryAvoidsCalibrationAndAttemptHistoryAnchorsWithoutNumbers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let athlete = AthleteProfile()
        let numeric = ExerciseVariation(name: "Numeric", metric: .seconds)
        let attempt = ExerciseVariation(name: "Attempt", metric: .reps)
        context.insert(athlete)
        context.insert(numeric)
        context.insert(attempt)
        addPerformance(variation: numeric, seconds: [12, 10, 8], at: now, context: context)
        addAttemptPerformance(variation: attempt, at: now, context: context)
        try context.save()

        let numericResult = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: numeric.id,
            mode: .duration,
            context: context,
            asOf: now
        )
        guard case let .ready(numericState) = numericResult else {
            return XCTFail("Expected exact hold history to avoid calibration")
        }
        XCTAssertEqual(numericState.workingSetValues, ThreeWorkingSetValues(first: 12, second: 10, third: 8))

        let attemptResult = try PrescriptionStateService.initializeIfPossible(
            athleteID: athlete.id,
            variationID: attempt.id,
            mode: .attempts,
            context: context,
            asOf: now
        )
        guard case let .ready(attemptState) = attemptResult else {
            return XCTFail("Expected real attempt history to establish an attempt basis")
        }
        XCTAssertEqual(attemptState.mode, .attempts)
        XCTAssertEqual(attemptState.basisKind, .realPerformance)
        XCTAssertNil(attemptState.workingSetValues)
    }

    private func addPerformance(
        variation: ExerciseVariation,
        reps: [Int]? = nil,
        seconds: [Int]? = nil,
        at date: Date,
        context: ModelContext
    ) {
        let exercise = variation.exercise ?? Exercise(name: "Family", metric: variation.metric)
        let session = WorkoutSession(workoutName: "History")
        session.startedAt = date
        session.completedAt = date
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        context.insert(session)
        context.insert(log)
        session.exerciseLogs = [log]
        for index in 0..<3 {
            let set = SetLog(
                setNumber: index + 1,
                reps: reps?[index],
                seconds: seconds?[index],
                variation: variation,
                exerciseLog: log
            )
            context.insert(set)
            log.sets.append(set)
        }
    }

    private func addAttemptPerformance(
        variation: ExerciseVariation,
        at date: Date,
        context: ModelContext
    ) {
        let exercise = variation.exercise ?? Exercise(name: "Family", metric: variation.metric)
        let session = WorkoutSession(workoutName: "Attempt history")
        session.startedAt = date
        session.completedAt = date
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(
            setNumber: 1,
            effortKind: .attempt,
            attemptOutcome: .unsuccessful,
            variation: variation,
            exerciseLog: log
        )
        context.insert(session)
        context.insert(log)
        context.insert(set)
        session.exerciseLogs = [log]
        log.sets = [set]
    }

    private func makeContainer(at url: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(url: url)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        return try ModelContainer(
            for: Exercise.self, ExerciseVariation.self, WorkoutTemplate.self,
            WorkoutTemplateExercise.self, WorkoutSession.self, ExerciseLog.self, SetLog.self,
            JourneyLevel.self, LevelRequirement.self, Requirement.self, RequirementImplication.self,
            Skill.self, SkillStage.self, EquipmentDefinition.self, AthleteProfile.self,
            EquipmentAvailability.self, SkillGoal.self, SkillStageConnection.self,
            SkillExerciseLink.self, VariationEquipmentMapping.self,
            VariationEquipmentSetup.self, VariationEquipmentItem.self,
            ExercisePrescriptionState.self,
            configurations: configuration
        )
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PrescriptionState-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }
}
