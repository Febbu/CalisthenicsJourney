import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class AthleteProfileTests: XCTestCase {
    func testLockedEquipmentCatalogHasStableDistinctIdentities() {
        XCTAssertEqual(EquipmentCatalog.items.count, 17)
        XCTAssertEqual(Set(EquipmentCatalog.items.map(\.id)).count, 17)
        XCTAssertEqual(Set(EquipmentCatalog.items.map(\.kind)).count, 17)
        XCTAssertNotEqual(item(.latPulldownMachine).id, item(.seatedCableRowMachine).id)
        XCTAssertEqual(item(.suspensionTrainer).kind.rawValue, "suspensionTrainer")
        XCTAssertFalse(EquipmentCatalog.items.contains { $0.displayName == "Floor" || $0.displayName == "Wall" })
    }

    func testProfileAndEquipmentBootstrapAreIdempotentAndPersistAcrossFreshContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        try context.save()

        let fresh = ModelContext(container)
        let profiles = try fresh.fetch(FetchDescriptor<AthleteProfile>())
        let definitions = try fresh.fetch(FetchDescriptor<EquipmentDefinition>())
        let availability = try fresh.fetch(FetchDescriptor<EquipmentAvailability>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.id, AthleteProfileBootstrap.localProfileID)
        XCTAssertEqual(definitions.count, 17)
        XCTAssertEqual(availability.count, 17)
        XCTAssertTrue(availability.allSatisfy { !$0.isAvailable })
    }

    func testBootstrapPreservesExistingWorkoutHistory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WorkoutSession(workoutName: "History")
        context.insert(session)
        try context.save()

        try AthleteProfileBootstrap.installIfNeeded(context: context)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<WorkoutSession>()).map(\.id), [session.id])
    }

    func testAvailabilityPersistsAndAlternativeEquipmentUsesOrSemantics() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        EquipmentAvailabilityManager.setAvailable(true, equipmentID: item(.lowBar).id, profile: profile)
        try context.save()

        let requirement = EquipmentRequirement(options: [
            EquipmentSetupOption([.lowBar]),
            EquipmentSetupOption([.smithMachine]),
            EquipmentSetupOption([.gymnasticRings]),
            EquipmentSetupOption([.suspensionTrainer])
        ])
        XCTAssertTrue(requirement.isSatisfied(by: [.lowBar]))
        XCTAssertTrue(requirement.isSatisfied(by: [.smithMachine]))
        XCTAssertTrue(requirement.isSatisfied(by: [.gymnasticRings]))
        XCTAssertTrue(requirement.isSatisfied(by: [.suspensionTrainer]))
        XCTAssertTrue(requirement.isSatisfied(by: [.lowBar, .gymnasticRings]))
        XCTAssertFalse(requirement.isSatisfied(by: []))

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: fetched), [.lowBar])
    }

    func testCompoundEquipmentSupportsAndWithinOptionOrBetweenOptions() {
        let requirement = EquipmentRequirement(options: [
            EquipmentSetupOption([.benchOrBox, .dumbbells]),
            EquipmentSetupOption([.chestOrShoulderPressMachine])
        ])
        XCTAssertFalse(requirement.isSatisfied(by: [.benchOrBox]))
        XCTAssertFalse(requirement.isSatisfied(by: [.dumbbells]))
        XCTAssertTrue(requirement.isSatisfied(by: [.benchOrBox, .dumbbells]))
        XCTAssertTrue(requirement.isSatisfied(by: [.chestOrShoulderPressMachine]))
    }

    func testSixGoalsRemainSelectedAndReselectionAppendsWithoutChangingEquipment() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        EquipmentAvailabilityManager.setAvailable(true, equipmentID: item(.pullUpBar).id, profile: profile)
        let skills = (1...6).map { Skill(name: "Skill \($0)", emoji: "") }
        skills.forEach(context.insert)
        skills.forEach { SkillGoalManager.select(skill: $0, profile: profile, context: context) }
        XCTAssertEqual(SkillGoalManager.orderedSelectedGoals(profile.skillGoals).count, 6)

        SkillGoalManager.deselect(skillID: skills[1].id, profile: profile, context: context)
        XCTAssertEqual(SkillGoalManager.orderedSelectedGoals(profile.skillGoals).map(\.skillID), [skills[0].id, skills[2].id, skills[3].id, skills[4].id, skills[5].id])
        SkillGoalManager.select(skill: skills[1], profile: profile, context: context)
        XCTAssertEqual(SkillGoalManager.orderedSelectedGoals(profile.skillGoals).last?.skillID, skills[1].id)
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: profile), [.pullUpBar])
    }

    func testReorderNormalizesDuplicatesAndPersistsDeterministically() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let skills = (1...4).map { Skill(name: "Skill \($0)", emoji: "") }
        skills.forEach(context.insert)
        let goals = skills.map { SkillGoalManager.select(skill: $0, profile: profile, context: context) }
        goals.forEach { $0.priority = 2 }
        let stable = SkillGoalManager.orderedSelectedGoals(goals)
        SkillGoalManager.reorder(
            selectedGoalIDs: [stable[3].id, stable[0].id, stable[3].id],
            profile: profile,
            context: context
        )
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let ordered = SkillGoalManager.orderedSelectedGoals(fetched.skillGoals)
        XCTAssertEqual(ordered.map(\.id), [stable[3].id, stable[0].id, stable[1].id, stable[2].id])
        XCTAssertEqual(ordered.map(\.priority), [0, 1, 2, 3])
    }

    func testFocusResolverUsesFirstThreeEligibleWithoutMutatingPriority() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let skills = (1...6).map { Skill(name: "Skill \($0)", emoji: "") }
        skills.forEach(context.insert)
        let goals = skills.map { SkillGoalManager.select(skill: $0, profile: profile, context: context) }
        let originalPriorities = goals.map(\.priority)

        let all = SkillFocusResolver.resolve(goals: goals, masteredSkillIDs: [], trainabilityBySkillID: [:])
        XCTAssertEqual(all.focusGoalIDs, Array(goals.prefix(3).map(\.id)))
        XCTAssertEqual(all.queuedGoalIDs, Array(goals.dropFirst(3).map(\.id)))

        let mixed = SkillFocusResolver.resolve(
            goals: goals,
            masteredSkillIDs: [skills[0].id],
            trainabilityBySkillID: [skills[1].id: .temporarilyUnavailable]
        )
        XCTAssertEqual(mixed.focusGoalIDs, [goals[2].id, goals[3].id, goals[4].id])
        XCTAssertEqual(mixed.queuedGoalIDs, [goals[5].id])
        XCTAssertEqual(goals.map(\.priority), originalPriorities)

        let restored = SkillFocusResolver.resolve(goals: goals, masteredSkillIDs: [], trainabilityBySkillID: [:])
        XCTAssertEqual(restored.focusGoalIDs, Array(goals.prefix(3).map(\.id)))
    }

    func testSelectionEquipmentAndPriorityDoNotGateOrMutateMastery() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let skill = Skill(name: "Evidence Skill", emoji: "")
        let stage = SkillStage(name: "Stage", orderIndex: 0, skill: skill)
        skill.stages = [stage]
        let exercise = Exercise(name: "Movement", metric: .reps)
        let variation = ExerciseVariation(name: "Exact", metric: .reps, exercise: exercise)
        let requirement = Requirement(title: "Proof", exerciseID: exercise.id, variationID: variation.id, metric: .reps, evidenceKind: .reps, targetReps: 5, skillStage: stage)
        stage.requirements = [requirement]
        context.insert(skill)
        context.insert(stage)
        context.insert(exercise)
        context.insert(variation)
        context.insert(requirement)
        let session = WorkoutSession(workoutName: "Proof")
        let log = ExerciseLog(exercise: exercise, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, reps: 5, variation: variation, exerciseLog: log)
        log.sets = [set]
        session.exerciseLogs = [log]
        context.insert(session)
        context.insert(log)
        context.insert(set)

        SkillGoalManager.select(skill: skill, profile: profile, context: context)
        SkillGoalManager.deselect(skillID: skill.id, profile: profile, context: context)
        EquipmentAvailabilityManager.setAvailable(false, equipmentID: item(.pullUpBar).id, profile: profile)

        XCTAssertTrue(RequirementEvaluator.evaluate(requirement, against: [session]).isSatisfied)
        XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [session]))
    }

    func testBootstrapRepairsNullifiedEquipmentRelationshipWithoutLosingAvailability() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let equipmentID = item(.pullUpBar).id
        EquipmentAvailabilityManager.setAvailable(true, equipmentID: equipmentID, profile: profile)
        let row = try XCTUnwrap(profile.equipmentAvailability.first(where: {
            $0.equipmentID == equipmentID
        }))
        row.equipment = nil
        try context.save()

        let brokenContext = ModelContext(container)
        let brokenProfile = try XCTUnwrap(try brokenContext.fetch(FetchDescriptor<AthleteProfile>()).first)
        let brokenRow = try XCTUnwrap(brokenProfile.equipmentAvailability.first(where: {
            $0.equipmentID == equipmentID
        }))
        XCTAssertNil(brokenRow.equipment)
        XCTAssertTrue(brokenRow.isAvailable)
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: brokenProfile), [.pullUpBar])

        let wrongDefinition = try XCTUnwrap(
            try brokenContext.fetch(FetchDescriptor<EquipmentDefinition>()).first(where: {
                $0.id == item(.dumbbells).id
            })
        )
        brokenRow.equipment = wrongDefinition
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: brokenProfile), [.pullUpBar])

        try AthleteProfileBootstrap.installIfNeeded(context: brokenContext)
        try brokenContext.save()

        let repairedContext = ModelContext(container)
        let repairedProfile = try XCTUnwrap(try repairedContext.fetch(FetchDescriptor<AthleteProfile>()).first)
        let repairedRows = repairedProfile.equipmentAvailability.filter { $0.equipmentID == equipmentID }
        XCTAssertEqual(repairedRows.count, 1)
        XCTAssertTrue(try XCTUnwrap(repairedRows.first).isAvailable)
        XCTAssertEqual(repairedRows.first?.equipment?.id, equipmentID)
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: repairedProfile), [.pullUpBar])
    }

    func testDuplicateAvailabilityRowsMergeDeterministicallyAcrossFreshContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let lowBar = try XCTUnwrap(definitions.first(where: { $0.id == item(.lowBar).id }))
        let rings = try XCTUnwrap(definitions.first(where: { $0.id == item(.gymnasticRings).id }))

        let lowBarDuplicate = EquipmentAvailability(equipment: lowBar, isAvailable: false, profile: profile)
        let ringsTrue = EquipmentAvailability(equipment: rings, isAvailable: true, profile: profile)
        let ringsBroken = EquipmentAvailability(equipment: rings, isAvailable: false, profile: profile)
        ringsBroken.equipment = nil
        context.insert(lowBarDuplicate)
        context.insert(ringsTrue)
        context.insert(ringsBroken)
        try context.save()

        try AthleteProfileBootstrap.installIfNeeded(context: context)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let lowBarRows = fetched.equipmentAvailability.filter { $0.equipmentID == lowBar.id }
        let ringsRows = fetched.equipmentAvailability.filter { $0.equipmentID == rings.id }
        XCTAssertEqual(lowBarRows.count, 1)
        XCTAssertFalse(try XCTUnwrap(lowBarRows.first).isAvailable)
        XCTAssertEqual(ringsRows.count, 1)
        XCTAssertTrue(try XCTUnwrap(ringsRows.first).isAvailable)
        XCTAssertEqual(ringsRows.first?.equipment?.id, rings.id)
        XCTAssertEqual(EquipmentAvailabilityManager.availableKinds(for: fetched), [.gymnasticRings])
    }

    func testAvailabilityManagerUpdatesAllMalformedDuplicatesDeterministically() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definition = try XCTUnwrap(
            try context.fetch(FetchDescriptor<EquipmentDefinition>()).first(where: {
                $0.id == item(.dumbbells).id
            })
        )
        context.insert(EquipmentAvailability(equipment: definition, isAvailable: true, profile: profile))

        EquipmentAvailabilityManager.setAvailable(false, equipmentID: definition.id, profile: profile)
        XCTAssertTrue(profile.equipmentAvailability.filter { $0.equipmentID == definition.id }.allSatisfy {
            !$0.isAvailable
        })
    }

    func testDuplicateSkillGoalsRepairToOneSelectedSemanticGoalAndPersist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let skill = Skill(name: "Duplicate", emoji: "")
        context.insert(skill)
        let selectedHigh = SkillGoal(skill: skill, priority: 5, profile: profile)
        let selectedLow = SkillGoal(skill: skill, priority: 2, profile: profile)
        let deselected = SkillGoal(skill: skill, priority: -4, isSelected: false, profile: profile)
        context.insert(selectedHigh)
        context.insert(selectedLow)
        context.insert(deselected)

        let unresolvedFocus = SkillFocusResolver.resolve(
            goals: profile.skillGoals,
            masteredSkillIDs: [],
            trainabilityBySkillID: [:]
        )
        XCTAssertEqual(unresolvedFocus.focusGoalIDs.count, 1)

        let selected = SkillGoalManager.select(skill: skill, profile: profile, context: context)
        XCTAssertTrue(selected.isSelected)
        XCTAssertEqual(selected.priority, 0)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let duplicates = fetched.skillGoals.filter { $0.skillID == skill.id }
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertTrue(try XCTUnwrap(duplicates.first).isSelected)
        XCTAssertEqual(duplicates.first?.priority, 0)
    }

    func testDeselectRepairsMalformedSkillGoalDuplicatesToOneInactiveRow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let skill = Skill(name: "Duplicate", emoji: "")
        context.insert(skill)
        context.insert(SkillGoal(skill: skill, priority: 9, profile: profile))
        context.insert(SkillGoal(skill: skill, priority: 1, isSelected: false, profile: profile))

        SkillGoalManager.deselect(skillID: skill.id, profile: profile, context: context)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let rows = fetched.skillGoals.filter { $0.skillID == skill.id }
        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(try XCTUnwrap(rows.first).isSelected)
        XCTAssertTrue(SkillGoalManager.orderedSelectedGoals(fetched.skillGoals).isEmpty)
    }

    private func item(_ kind: EquipmentKind) -> EquipmentCatalogItem {
        EquipmentCatalog.items.first(where: { $0.kind == kind })!
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Exercise.self, ExerciseVariation.self, WorkoutTemplate.self,
            WorkoutTemplateExercise.self, WorkoutSession.self, ExerciseLog.self, SetLog.self,
            JourneyLevel.self, LevelRequirement.self, Requirement.self, RequirementImplication.self,
            Skill.self, SkillStage.self, EquipmentDefinition.self, AthleteProfile.self,
            EquipmentAvailability.self, SkillGoal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
