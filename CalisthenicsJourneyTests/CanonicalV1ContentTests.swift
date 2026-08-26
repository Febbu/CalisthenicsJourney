import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class CanonicalV1ContentTests: XCTestCase {
    func testFreshInstallationContainsExactlyTheNineCanonicalSkillsWithStableIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)

        let skills = try context.fetch(FetchDescriptor<Skill>())
        XCTAssertEqual(skills.count, 9)
        XCTAssertEqual(Set(skills.map(\.name)), Set(CanonicalV1Content.skillNames))
        XCTAssertEqual(
            Set(skills.map(\.id)),
            Set(CanonicalV1Content.skillKeys.map { CanonicalV1Content.id(for: "skill.\($0)") })
        )
        XCTAssertEqual(
            CanonicalV1Content.id(for: "skill.push-up"),
            CanonicalV1Content.id(for: "skill.push-up")
        )
        XCTAssertNotEqual(
            CanonicalV1Content.id(for: "skill.push-up"),
            CanonicalV1Content.id(for: "skill.pull-up")
        )
    }

    func testRepeatedInstallationIsIdempotentAndDoesNotOverwriteRenamedContent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let firstCounts = try entityCounts(context)
        let pushUp = try XCTUnwrap(try context.fetch(FetchDescriptor<Skill>()).first {
            $0.id == CanonicalV1Content.id(for: "skill.push-up")
        })
        let strictVariation = try XCTUnwrap(try context.fetch(FetchDescriptor<ExerciseVariation>()).first {
            $0.id == CanonicalV1Content.id(for: "variation.strict-push-up")
        })
        pushUp.name = "My Push Skill"
        strictVariation.name = "My Standard Press"
        try context.save()

        try SeedData.installIfNeeded(context: context, existingExerciseCount: 999)

        XCTAssertEqual(try entityCounts(context), firstCounts)
        XCTAssertEqual(pushUp.name, "My Push Skill")
        XCTAssertEqual(strictVariation.name, "My Standard Press")
    }

    func testEveryCanonicalTopologyValidatesAndHasOnePrimaryCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let stages = try context.fetch(FetchDescriptor<SkillStage>())
        let connections = try context.fetch(FetchDescriptor<SkillStageConnection>())
        let skills = try canonicalSkills(context)

        XCTAssertEqual(stages.count, 64)
        for skill in skills {
            let skillStageIDs = Set(skill.stages.map(\.id))
            let localConnections = connections.filter {
                skillStageIDs.contains($0.sourceStageID) || skillStageIDs.contains($0.destinationStageID)
            }
            let destinationIDs = Set(localConnections.map(\.destinationStageID))
            let rootIDs = skillStageIDs.subtracting(destinationIDs)
            let result = SkillTopologyValidator.validate(
                skill: skill,
                allStages: stages,
                connections: localConnections,
                intendedRootStageIDs: rootIDs
            )
            XCTAssertTrue(result.isValid, "\(skill.name): \(result.issues)")
            XCTAssertEqual(skill.stages.filter { $0.isSkillCompletion && $0.nodeKind == .primary }.count, 1)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<RequirementImplication>()).isEmpty)
    }

    func testSafeHandstandBailIsMasterableNonblockingSafetyBranch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let stages = try context.fetch(FetchDescriptor<SkillStage>())
        let connections = try context.fetch(FetchDescriptor<SkillStageConnection>())
        let links = try context.fetch(FetchDescriptor<SkillExerciseLink>())
        let bail = try stage("stage.handstand.safe-bail", in: stages)
        let wallHold = try stage("stage.handstand.chest-wall-30", in: stages)
        let wallBalance = try stage("stage.handstand.wall-balance", in: stages)

        XCTAssertEqual(bail.nodeKind, .safety)
        XCTAssertFalse(bail.isSkillCompletion)
        XCTAssertEqual(bail.requirements.count, 1)
        XCTAssertEqual(bail.requirements.first?.evidenceKind, .successfulAttempt)
        XCTAssertTrue(connections.contains { $0.sourceStageID == wallHold.id && $0.destinationStageID == bail.id })
        XCTAssertTrue(connections.contains { $0.sourceStageID == wallHold.id && $0.destinationStageID == wallBalance.id })
        XCTAssertFalse(connections.contains { $0.sourceStageID == bail.id && $0.destinationStageID == wallBalance.id })
        XCTAssertTrue(links.contains { $0.stageID == bail.id && $0.role == .safetyPractice })
    }

    func testApprovedBothSideNodesUseTwoIndependentRequirements() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let stages = try context.fetch(FetchDescriptor<SkillStage>())
        let keys = [
            "stage.l-sit.one-leg", "stage.pistol-squat.full-1", "stage.pistol-squat.full-3",
            "stage.pistol-squat.full-5", "stage.front-lever.one-leg", "stage.planche.one-leg"
        ]
        for key in keys {
            let requirements = try stage(key, in: stages).requirements
            XCTAssertEqual(requirements.count, 2, key)
            XCTAssertEqual(Set(requirements.map(\.side)), [.left, .right], key)
            XCTAssertEqual(Set(requirements.compactMap(\.variationID)).count, 1, key)
        }
    }

    func testStrictPullUpVariationIsSharedAcrossSkillsAndFoundationEvidence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.installIfNeeded(context: context, existingExerciseCount: 0)
        let variationID = CanonicalV1Content.id(for: "variation.strict-pull-up")
        let links = try context.fetch(FetchDescriptor<SkillExerciseLink>()).filter { $0.variationID == variationID }
        let requirements = try context.fetch(FetchDescriptor<Requirement>()).filter { $0.variationID == variationID }
        let variations = try context.fetch(FetchDescriptor<ExerciseVariation>()).filter { $0.id == variationID }
        let expectedSkillIDs = Set(["pull-up", "muscle-up", "front-lever"].map {
            CanonicalV1Content.id(for: "skill.\($0)")
        })

        XCTAssertEqual(variations.count, 1)
        XCTAssertTrue(expectedSkillIDs.isSubset(of: Set(links.map(\.skillID))))
        XCTAssertTrue(expectedSkillIDs.isSubset(of: Set(requirements.compactMap { $0.skillStage?.skill?.id })))
    }

    func testCanonicalContentPersistsAcrossFreshContextAndEquipmentMappingsStayExplicit() throws {
        let container = try makeContainer()
        try SeedData.installIfNeeded(context: container.mainContext, existingExerciseCount: 0)

        let fresh = ModelContext(container)
        let skills = try canonicalSkills(fresh)
        let mappings = try fresh.fetch(FetchDescriptor<VariationEquipmentMapping>())
        XCTAssertEqual(skills.count, 9)
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: CanonicalV1Content.id(for: "variation.strict-push-up"),
                mappings: mappings,
                availableEquipmentIDs: []
            ),
            .available
        )
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: CanonicalV1Content.id(for: "variation.strict-pull-up"),
                mappings: mappings,
                availableEquipmentIDs: []
            ),
            .unavailable
        )
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: CanonicalV1Content.id(for: "variation.strict-pull-up"),
                mappings: mappings,
                availableEquipmentIDs: [equipmentID(.pullUpBar)]
            ),
            .available
        )
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: CanonicalV1Content.id(for: "variation.assisted-pull-up"),
                mappings: mappings,
                availableEquipmentIDs: [equipmentID(.pullUpBar), equipmentID(.resistanceBands)]
            ),
            .unknown
        )
    }

    func testSeedMigrationPreservesLegacyHistoryProfileAndGoalState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        EquipmentAvailabilityManager.setAvailable(true, equipmentID: equipmentID(.dumbbells), profile: profile)
        let legacyExercise = Exercise(name: "Customized legacy movement", metric: .reps)
        let legacySkill = Skill(name: "Customized legacy goal", emoji: "")
        let legacyGoal = SkillGoal(skill: legacySkill, priority: 0, profile: profile)
        let session = WorkoutSession(workoutName: "Historical workout")
        let log = ExerciseLog(exercise: legacyExercise, orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, reps: 17, exerciseLog: log)
        context.insert(legacyExercise)
        context.insert(legacySkill)
        context.insert(legacyGoal)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        profile.skillGoals = [legacyGoal]
        session.exerciseLogs = [log]
        log.sets = [set]
        try context.save()

        try SeedData.installIfNeeded(context: context, existingExerciseCount: 1)

        XCTAssertNotNil(try context.fetch(FetchDescriptor<Exercise>()).first { $0.id == legacyExercise.id })
        XCTAssertNotNil(try context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == session.id })
        XCTAssertNotNil(try context.fetch(FetchDescriptor<SetLog>()).first { $0.id == set.id && $0.reps == 17 })
        XCTAssertNotNil(try context.fetch(FetchDescriptor<Skill>()).first { $0.id == legacySkill.id })
        XCTAssertTrue(profile.skillGoals.contains { $0.id == legacyGoal.id && $0.isSelected && $0.priority == 0 })
        XCTAssertTrue(profile.equipmentAvailability.contains {
            $0.equipmentID == equipmentID(.dumbbells) && $0.isAvailable
        })
        XCTAssertEqual(try canonicalSkills(context).count, 9)
    }

    private func stage(_ key: String, in stages: [SkillStage]) throws -> SkillStage {
        try XCTUnwrap(stages.first { $0.id == CanonicalV1Content.id(for: key) }, key)
    }

    private func canonicalSkills(_ context: ModelContext) throws -> [Skill] {
        let ids = Set(CanonicalV1Content.skillKeys.map { CanonicalV1Content.id(for: "skill.\($0)") })
        return try context.fetch(FetchDescriptor<Skill>()).filter { ids.contains($0.id) }
    }

    private func equipmentID(_ kind: EquipmentKind) -> UUID {
        EquipmentCatalog.items.first { $0.kind == kind }!.id
    }

    private func entityCounts(_ context: ModelContext) throws -> [String: Int] {
        [
            "skills": try context.fetchCount(FetchDescriptor<Skill>()),
            "stages": try context.fetchCount(FetchDescriptor<SkillStage>()),
            "requirements": try context.fetchCount(FetchDescriptor<Requirement>()),
            "exercises": try context.fetchCount(FetchDescriptor<Exercise>()),
            "variations": try context.fetchCount(FetchDescriptor<ExerciseVariation>()),
            "connections": try context.fetchCount(FetchDescriptor<SkillStageConnection>()),
            "links": try context.fetchCount(FetchDescriptor<SkillExerciseLink>()),
            "mappings": try context.fetchCount(FetchDescriptor<VariationEquipmentMapping>()),
            "setups": try context.fetchCount(FetchDescriptor<VariationEquipmentSetup>()),
            "items": try context.fetchCount(FetchDescriptor<VariationEquipmentItem>())
        ]
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Exercise.self, ExerciseVariation.self, WorkoutTemplate.self,
            WorkoutTemplateExercise.self, WorkoutSession.self, ExerciseLog.self, SetLog.self,
            JourneyLevel.self, LevelRequirement.self, Requirement.self, RequirementImplication.self,
            Skill.self, SkillStage.self, EquipmentDefinition.self, AthleteProfile.self,
            EquipmentAvailability.self, SkillGoal.self, SkillStageConnection.self,
            SkillExerciseLink.self, VariationEquipmentMapping.self,
            VariationEquipmentSetup.self, VariationEquipmentItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
