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
            metric: .reps,
            evidenceKind: .reps,
            side: .right,
            targetReps: 10,
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
        context.insert(exercise)
        context.insert(variation)
        context.insert(skill)
        context.insert(sourceStage)
        context.insert(impliedStage)
        context.insert(source)
        context.insert(implied)
        context.insert(implication)
        try context.save()

        let persistedRequirement = try XCTUnwrap(
            context.fetch(FetchDescriptor<Requirement>()).first { $0.id == source.id }
        )
        let persistedImplication = try XCTUnwrap(
            context.fetch(FetchDescriptor<RequirementImplication>()).first
        )
        XCTAssertEqual(persistedRequirement.variationID, variation.id)
        XCTAssertEqual(persistedRequirement.evidenceKind, .reps)
        XCTAssertEqual(persistedRequirement.side, .right)
        XCTAssertEqual(persistedImplication.sourceRequirementID, source.id)
        XCTAssertEqual(persistedImplication.impliedRequirementID, implied.id)
        XCTAssertEqual(persistedImplication.sourceRequirement?.id, source.id)
        XCTAssertEqual(persistedImplication.impliedRequirement?.id, implied.id)
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
