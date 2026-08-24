import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class RequirementMigrationTests: XCTestCase {
    func testLegacyLevelRequirementMigratesWithoutRemovingLegacyData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Original name", metric: .weightAndReps)
        let level = JourneyLevel(number: 1, name: "Foundation", isUnlocked: true)
        let legacy = LevelRequirement(
            title: "Legacy requirement",
            exerciseID: exercise.id,
            metric: .weightAndReps,
            targetReps: 10,
            targetWeight: 100,
            confirmationsNeeded: 3,
            level: level
        )
        context.insert(exercise)
        context.insert(level)
        context.insert(legacy)
        level.requirements = [legacy]
        try context.save()

        try RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
        try context.save()

        let migrated = try XCTUnwrap(context.fetch(FetchDescriptor<Requirement>()).first)
        XCTAssertEqual(migrated.id, legacy.id)
        XCTAssertEqual(migrated.title, legacy.title)
        XCTAssertEqual(migrated.exerciseID, legacy.exerciseID)
        XCTAssertEqual(migrated.metric, legacy.metric)
        XCTAssertEqual(migrated.targetReps, legacy.targetReps)
        XCTAssertEqual(migrated.targetWeight, legacy.targetWeight)
        XCTAssertEqual(migrated.confirmationsNeeded, legacy.confirmationsNeeded)
        XCTAssertEqual(migrated.journeyLevel?.id, level.id)
        XCTAssertNil(migrated.skillStage)
        XCTAssertTrue(migrated.hasExactlyOneOwner)
        XCTAssertEqual(level.genericRequirements.map(\.id), [legacy.id])

        let preservedLegacy = try context.fetch(FetchDescriptor<LevelRequirement>())
        XCTAssertEqual(preservedLegacy.count, 1)
        XCTAssertEqual(preservedLegacy.first?.level?.id, level.id)
    }

    func testLegacyMigrationIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let level = JourneyLevel(number: 1, name: "Foundation")
        let legacy = LevelRequirement(
            title: "Legacy requirement",
            metric: .reps,
            targetReps: 10,
            level: level
        )
        context.insert(level)
        context.insert(legacy)
        try context.save()

        try RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
        try context.save()
        try RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Requirement>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LevelRequirement>()).count, 1)
    }

    func testRequirementInitializersSetExactlyOneOwner() {
        let level = JourneyLevel(number: 1, name: "Foundation")
        let skill = Skill(name: "Handstand", emoji: "🤸")
        let stage = SkillStage(name: "Wall Handstand", orderIndex: 0, skill: skill)

        let levelRequirement = Requirement(
            title: "Level requirement",
            metric: .reps,
            journeyLevel: level
        )
        let stageRequirement = Requirement(
            title: "Stage requirement",
            metric: .seconds,
            skillStage: stage
        )

        XCTAssertTrue(levelRequirement.hasExactlyOneOwner)
        XCTAssertNotNil(levelRequirement.journeyLevel)
        XCTAssertNil(levelRequirement.skillStage)
        XCTAssertTrue(stageRequirement.hasExactlyOneOwner)
        XCTAssertNil(stageRequirement.journeyLevel)
        XCTAssertNotNil(stageRequirement.skillStage)
    }

    func testCanonicalRequirementAndImplicationRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Movement", metric: .reps)
        let variation = ExerciseVariation(name: "Exact variation", metric: .reps, exercise: exercise)
        let skill = Skill(name: "Skill", emoji: "")
        let sourceStage = SkillStage(name: "Source", orderIndex: 1, skill: skill)
        let impliedStage = SkillStage(name: "Implied", orderIndex: 0, skill: skill)
        let source = Requirement(
            title: "Source",
            exerciseID: exercise.id,
            variationID: variation.id,
            metric: .weightAndReps,
            evidenceKind: .weightAndReps,
            side: .right,
            targetReps: 10,
            targetWeight: 25,
            targetSeconds: 30,
            skillStage: sourceStage
        )
        let implied = Requirement(
            title: "Implied",
            exerciseID: exercise.id,
            variationID: variation.id,
            metric: .reps,
            evidenceKind: .reps,
            side: .right,
            targetReps: 5,
            skillStage: impliedStage
        )
        let implication = RequirementImplication(source: source, implies: implied)
        let sourceID = source.id
        let impliedID = implied.id
        let implicationID = implication.id
        let variationID = variation.id
        context.insert(exercise)
        context.insert(variation)
        context.insert(skill)
        context.insert(sourceStage)
        context.insert(impliedStage)
        context.insert(source)
        context.insert(implied)
        context.insert(implication)
        try context.save()

        let verificationContext = ModelContext(container)
        let persistedRequirement = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<Requirement>()).first { $0.id == sourceID }
        )
        let persistedImplication = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<RequirementImplication>()).first { $0.id == implicationID }
        )
        XCTAssertEqual(persistedRequirement.id, sourceID)
        XCTAssertEqual(persistedRequirement.variationID, variationID)
        XCTAssertEqual(persistedRequirement.evidenceKind, .weightAndReps)
        XCTAssertEqual(persistedRequirement.side, .right)
        XCTAssertEqual(persistedRequirement.targetReps, 10)
        XCTAssertEqual(persistedRequirement.targetWeight, 25)
        XCTAssertEqual(persistedRequirement.targetSeconds, 30)
        XCTAssertEqual(persistedRequirement.skillStage?.id, sourceStage.id)
        XCTAssertEqual(persistedImplication.sourceRequirementID, sourceID)
        XCTAssertEqual(persistedImplication.impliedRequirementID, impliedID)
        XCTAssertEqual(persistedImplication.sourceRequirement?.id, sourceID)
        XCTAssertEqual(persistedImplication.impliedRequirement?.id, impliedID)
    }

    func testPersistedEvidenceDeletionReevaluatesMasteryFromFreshHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Movement", metric: .reps)
        let variation = ExerciseVariation(name: "Exact variation", metric: .reps, exercise: exercise)
        let stage = SkillStage(name: "Stage", orderIndex: 0)
        let requirement = Requirement(
            title: "Five reps",
            exerciseID: exercise.id,
            variationID: variation.id,
            metric: .reps,
            evidenceKind: .reps,
            targetReps: 5,
            skillStage: stage
        )
        let firstSession = WorkoutSession(workoutName: "First")
        let firstLog = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: firstSession)
        let firstSet = SetLog(setNumber: 1, reps: 5, variation: variation, exerciseLog: firstLog)
        let secondSession = WorkoutSession(workoutName: "Second")
        let secondLog = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: secondSession)
        let secondSet = SetLog(setNumber: 1, reps: 6, variation: variation, exerciseLog: secondLog)
        context.insert(exercise)
        context.insert(variation)
        context.insert(stage)
        context.insert(requirement)
        context.insert(firstSession)
        context.insert(firstLog)
        context.insert(firstSet)
        context.insert(secondSession)
        context.insert(secondLog)
        context.insert(secondSet)
        stage.requirements = [requirement]
        firstSession.exerciseLogs = [firstLog]
        firstLog.sets = [firstSet]
        secondSession.exerciseLogs = [secondLog]
        secondLog.sets = [secondSet]
        try context.save()

        let deletionContext = ModelContext(container)
        let persistedRequirement = try XCTUnwrap(deletionContext.fetch(FetchDescriptor<Requirement>()).first)
        var persistedSessions = try deletionContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(RequirementEvaluator.evaluate(persistedRequirement, against: persistedSessions).isSatisfied)

        let persistedSets = try deletionContext.fetch(FetchDescriptor<SetLog>()).sorted { $0.reps ?? 0 < $1.reps ?? 0 }
        deletionContext.delete(try XCTUnwrap(persistedSets.first))
        try deletionContext.save()

        let oneProofContext = ModelContext(container)
        let oneProofRequirement = try XCTUnwrap(oneProofContext.fetch(FetchDescriptor<Requirement>()).first)
        persistedSessions = try oneProofContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(RequirementEvaluator.evaluate(oneProofRequirement, against: persistedSessions).isSatisfied)

        let lastProof = try XCTUnwrap(oneProofContext.fetch(FetchDescriptor<SetLog>()).first)
        oneProofContext.delete(lastProof)
        try oneProofContext.save()

        let noProofContext = ModelContext(container)
        let noProofRequirement = try XCTUnwrap(noProofContext.fetch(FetchDescriptor<Requirement>()).first)
        let noProofSessions = try noProofContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertFalse(RequirementEvaluator.evaluate(noProofRequirement, against: noProofSessions).isSatisfied)
    }

    func testFreshInstallSeedsOnlyGenericRequirements() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)

        let genericRequirements = try context.fetch(FetchDescriptor<Requirement>())
        let legacyRequirements = try context.fetch(FetchDescriptor<LevelRequirement>())
        let level = try XCTUnwrap(context.fetch(FetchDescriptor<JourneyLevel>()).first)

        XCTAssertEqual(genericRequirements.count, 3)
        XCTAssertTrue(legacyRequirements.isEmpty)
        XCTAssertEqual(level.genericRequirements.count, 3)
        XCTAssertTrue(level.genericRequirements.allSatisfy(\.hasExactlyOneOwner))
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
            configurations: configuration
        )
    }
}
