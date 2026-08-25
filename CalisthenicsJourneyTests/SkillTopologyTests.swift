import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class SkillTopologyTests: XCTestCase {
    func testLinearTopologyKeepsMasteryIndependentFromAccessibility() {
        let skill = Skill(name: "Linear", emoji: "")
        let a = stage("A", 0, skill)
        let b = stage("B", 1, skill)
        let c = stage("C", 2, skill)
        skill.stages = [a, b, c]
        let aVariation = requirementVariation(for: a)
        let bVariation = requirementVariation(for: b)
        let cVariation = requirementVariation(for: c)
        let connections = [
            SkillStageConnection(source: a, destination: b),
            SkillStageConnection(source: b, destination: c)
        ]

        var states = statesByID(skill, [session(cVariation)], connections)
        XCTAssertTrue(states[c.id]?.isMastered == true)
        XCTAssertFalse(states[c.id]?.isReachable == true)
        XCTAssertTrue(states[a.id]?.isReachable == true)
        XCTAssertFalse(states[b.id]?.isReachable == true)

        states = statesByID(skill, [session(aVariation), session(cVariation)], connections)
        XCTAssertTrue(states[b.id]?.isReachable == true)
        XCTAssertFalse(states[c.id]?.isReachable == true)
        XCTAssertTrue(states[c.id]?.isMastered == true)

        states = statesByID(
            skill,
            [session(aVariation), session(bVariation), session(cVariation)],
            connections
        )
        XCTAssertTrue(states[c.id]?.isReachable == true)
    }

    func testBranchAndExplicitAllOrAnyConvergence() {
        let skill = Skill(name: "Graph", emoji: "")
        let a = stage("A", 0, skill)
        let b = stage("B", 1, skill)
        let branch = stage("Branch", 2, skill)
        let all = stage("All", 3, skill, prerequisiteMode: .all)
        let any = stage("Any", 4, skill, prerequisiteMode: .any)
        skill.stages = [a, b, branch, all, any]
        let aVariation = requirementVariation(for: a)
        let bVariation = requirementVariation(for: b)
        _ = requirementVariation(for: branch)
        _ = requirementVariation(for: all)
        _ = requirementVariation(for: any)
        let connections = [
            SkillStageConnection(source: a, destination: branch),
            SkillStageConnection(source: a, destination: all),
            SkillStageConnection(source: b, destination: all),
            SkillStageConnection(source: a, destination: any),
            SkillStageConnection(source: b, destination: any)
        ]

        var states = statesByID(skill, [session(aVariation)], connections)
        XCTAssertTrue(states[branch.id]?.isReachable == true)
        XCTAssertFalse(states[all.id]?.isReachable == true)
        XCTAssertTrue(states[any.id]?.isReachable == true)
        XCTAssertFalse(states[b.id]?.isMastered == true)

        states = statesByID(skill, [session(aVariation), session(bVariation)], connections)
        XCTAssertTrue(states[all.id]?.isReachable == true)
    }

    func testOptionalSafetyBranchDoesNotBlockSkillCompletionAndCanBeMastered() {
        let skill = Skill(name: "Safety", emoji: "")
        let a = stage("A", 0, skill)
        let completion = stage("Completion", 1, skill, isCompletion: true)
        let safety = stage("Safety", 2, skill, kind: .safety)
        skill.stages = [a, completion, safety]
        let aVariation = requirementVariation(for: a)
        let completionVariation = requirementVariation(for: completion)
        let safetyMovement = movement(metric: .reps)
        safety.requirements = [Requirement(
            title: "Successful safety action",
            exerciseID: safetyMovement.exercise.id,
            variationID: safetyMovement.variation.id,
            metric: .reps,
            evidenceKind: .successfulAttempt,
            skillStage: safety
        )]
        let connections = [
            SkillStageConnection(source: a, destination: completion),
            SkillStageConnection(source: a, destination: safety)
        ]
        let mainHistory = [session(aVariation), session(completionVariation)]

        var states = statesByID(skill, mainHistory, connections)
        XCTAssertTrue(states[safety.id]?.isReachable == true)
        XCTAssertTrue(states[safety.id]?.isOptional == true)
        XCTAssertFalse(states[safety.id]?.isMastered == true)
        XCTAssertTrue(SkillTopologyEngine.isSkillMastered(skill, against: mainHistory))

        let attempt = session(safetyMovement.variation, attempt: .successful)
        states = statesByID(skill, mainHistory + [attempt], connections)
        XCTAssertTrue(states[safety.id]?.isMastered == true)
        XCTAssertTrue(SkillTopologyEngine.isSkillMastered(skill, against: mainHistory + [attempt]))
    }

    func testNoCompletionNodeAndOptionalCompletionCannotMasterSkill() {
        let skill = Skill(name: "Incomplete", emoji: "")
        let optional = stage("Optional", 0, skill, kind: .optional, isCompletion: true)
        skill.stages = [optional]
        let variation = requirementVariation(for: optional)
        XCTAssertFalse(SkillTopologyEngine.isSkillMastered(skill, against: [session(variation)]))
    }

    func testSharedVariationLinksPersistWithoutCloningVariation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let shared = movement(metric: .reps)
        context.insert(shared.exercise)
        context.insert(shared.variation)
        let skills = (0..<3).map { Skill(name: "Skill \($0)", emoji: "") }
        let stages = skills.enumerated().map { stage("Stage", $0.offset, $0.element) }
        for index in skills.indices {
            skills[index].stages = [stages[index]]
            context.insert(skills[index])
            context.insert(stages[index])
            let role: SkillExerciseRole = index == 0 ? .direct : .support
            context.insert(SkillExerciseLink(
                skill: skills[index],
                stage: stages[index],
                variation: shared.variation,
                role: role
            ))
        }
        try context.save()

        let fresh = ModelContext(container)
        let links = try fresh.fetch(FetchDescriptor<SkillExerciseLink>())
        let variations = try fresh.fetch(FetchDescriptor<ExerciseVariation>())
        XCTAssertEqual(links.count, 3)
        XCTAssertEqual(Set(links.map(\.skillID)).count, 3)
        XCTAssertEqual(Set(links.map(\.variationID)), [shared.variation.id])
        XCTAssertEqual(variations.filter { $0.id == shared.variation.id }.count, 1)
        XCTAssertEqual(links.filter { $0.role == .direct }.count, 1)
        XCTAssertEqual(links.filter { $0.role == .support }.count, 2)
    }

    func testTopologyAndEveryExerciseRolePersistAcrossFreshContext() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let skill = Skill(name: "Persistent Graph", emoji: "")
        let source = stage("Source", 0, skill)
        let destination = stage(
            "Destination",
            1,
            skill,
            prerequisiteMode: .any,
            isCompletion: true
        )
        skill.stages = [source, destination]
        context.insert(skill)
        context.insert(source)
        context.insert(destination)
        let connection = SkillStageConnection(source: source, destination: destination)
        context.insert(connection)

        for role in SkillExerciseRole.allCases {
            let fixture = movement(metric: .reps)
            context.insert(fixture.exercise)
            context.insert(fixture.variation)
            context.insert(SkillExerciseLink(
                skill: skill,
                stage: destination,
                variation: fixture.variation,
                role: role
            ))
        }
        try context.save()

        let fresh = ModelContext(container)
        let fetchedStages = try fresh.fetch(FetchDescriptor<SkillStage>())
        let fetchedConnections = try fresh.fetch(FetchDescriptor<SkillStageConnection>())
        let fetchedLinks = try fresh.fetch(FetchDescriptor<SkillExerciseLink>())
        let fetchedDestination = try XCTUnwrap(fetchedStages.first { $0.id == destination.id })
        let fetchedConnection = try XCTUnwrap(fetchedConnections.first)
        XCTAssertEqual(fetchedDestination.prerequisiteMode, .any)
        XCTAssertTrue(fetchedDestination.isSkillCompletion)
        XCTAssertEqual(fetchedConnection.sourceStageID, source.id)
        XCTAssertEqual(fetchedConnection.destinationStageID, destination.id)
        XCTAssertEqual(fetchedConnection.sourceStage?.id, source.id)
        XCTAssertEqual(fetchedConnection.destinationStage?.id, destination.id)
        XCTAssertEqual(Set(fetchedLinks.compactMap(\.role)), Set(SkillExerciseRole.allCases))
    }

    func testEquipmentMappingsPersistAndResolveBaselineUnknownSingleOrAndCompoundRoutes() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())

        let baseline = movement(metric: .reps)
        let unknown = movement(metric: .reps)
        let bar = movement(metric: .reps)
        let alternatives = movement(metric: .reps)
        let compound = movement(metric: .reps)
        let compoundOrMachine = movement(metric: .reps)
        let movements = [baseline, unknown, bar, alternatives, compound, compoundOrMachine]
        movements.forEach {
            context.insert($0.exercise)
            context.insert($0.variation)
        }

        let baselineMapping = VariationEquipmentMapping(variation: baseline.variation, kind: .baselineOnly)
        context.insert(baselineMapping)
        let barMapping = mapping(
            bar.variation,
            [[definition(.pullUpBar, definitions)]],
            context
        )
        let alternativesMapping = mapping(
            alternatives.variation,
            [
                [definition(.lowBar, definitions)],
                [definition(.smithMachine, definitions)],
                [definition(.gymnasticRings, definitions)],
                [definition(.suspensionTrainer, definitions)]
            ],
            context
        )
        let compoundMapping = mapping(
            compound.variation,
            [[definition(.benchOrBox, definitions), definition(.dumbbells, definitions)]],
            context
        )
        let compoundOrMapping = mapping(
            compoundOrMachine.variation,
            [
                [definition(.benchOrBox, definitions), definition(.dumbbells, definitions)],
                [definition(.chestOrShoulderPressMachine, definitions)]
            ],
            context
        )
        try context.save()

        let fresh = ModelContext(container)
        let fetchedProfile = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let mappings = try fresh.fetch(FetchDescriptor<VariationEquipmentMapping>())
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: baseline.variation.id,
                mappings: mappings,
                profile: fetchedProfile
            ),
            .available
        )
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: unknown.variation.id,
                mappings: mappings,
                profile: fetchedProfile
            ),
            .unknown
        )
        XCTAssertEqual(resolve(bar.variation, mappings, []), .unavailable)
        XCTAssertEqual(resolve(bar.variation, mappings, [.pullUpBar]), .available)

        XCTAssertEqual(resolve(alternatives.variation, mappings, []), .unavailable)
        for kind in [EquipmentKind.lowBar, .smithMachine, .gymnasticRings, .suspensionTrainer] {
            XCTAssertEqual(resolve(alternatives.variation, mappings, [kind]), .available)
        }

        XCTAssertEqual(resolve(compound.variation, mappings, [.benchOrBox]), .unavailable)
        XCTAssertEqual(resolve(compound.variation, mappings, [.dumbbells]), .unavailable)
        XCTAssertEqual(resolve(compound.variation, mappings, [.benchOrBox, .dumbbells]), .available)
        XCTAssertEqual(resolve(compoundOrMachine.variation, mappings, [.chestOrShoulderPressMachine]), .available)
        XCTAssertEqual(resolve(compoundOrMachine.variation, mappings, [.benchOrBox, .dumbbells]), .available)

        XCTAssertEqual(barMapping.variationID, bar.variation.id)
        XCTAssertEqual(alternativesMapping.setups.count, 4)
        XCTAssertEqual(compoundMapping.setups.first?.items.count, 2)
        XCTAssertEqual(compoundOrMapping.setups.count, 2)
    }

    func testEquipmentItemRelationshipNullificationUsesDurableIdentity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let bar = definition(.pullUpBar, definitions)
        EquipmentAvailabilityManager.setAvailable(true, equipmentID: bar.id, profile: profile)
        let direct = movement(metric: .reps)
        context.insert(direct.exercise)
        context.insert(direct.variation)
        let persistedMapping = mapping(direct.variation, [[bar]], context)
        persistedMapping.setups.first?.items.first?.equipment = nil
        try context.save()

        let fresh = ModelContext(container)
        let fetchedProfile = try XCTUnwrap(try fresh.fetch(FetchDescriptor<AthleteProfile>()).first)
        let mappings = try fresh.fetch(FetchDescriptor<VariationEquipmentMapping>())
        let item = try XCTUnwrap(try fresh.fetch(FetchDescriptor<VariationEquipmentItem>()).first)
        XCTAssertNil(item.equipment)
        XCTAssertEqual(item.equipmentID, bar.id)
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: direct.variation.id,
                mappings: mappings,
                profile: fetchedProfile
            ),
            .available
        )
    }

    func testTrainabilityUsesDirectWorkNotUnavailableSupport() throws {
        let fixture = try trainabilityFixture()
        XCTAssertEqual(
            SkillTrainabilityResolver.resolve(
                skill: fixture.skill,
                against: [],
                connections: [],
                exerciseLinks: fixture.links,
                equipmentMappings: fixture.mappings,
                profile: fixture.profile
            ),
            .trainable
        )
    }

    func testTrainabilityFailsWhenOnlySupportIsAvailableAndRecoversThroughAlternativeDirectRoute() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let skill = Skill(name: "Trainability", emoji: "")
        let current = stage("Current", 0, skill)
        skill.stages = [current]
        _ = requirementVariation(for: current)
        context.insert(skill)
        context.insert(current)
        let direct = movement(metric: .reps)
        let support = movement(metric: .reps)
        [direct, support].forEach {
            context.insert($0.exercise)
            context.insert($0.variation)
        }
        let directLink = SkillExerciseLink(skill: skill, stage: current, variation: direct.variation, role: .direct)
        let supportLink = SkillExerciseLink(skill: skill, stage: current, variation: support.variation, role: .support)
        context.insert(directLink)
        context.insert(supportLink)
        let directMapping = mapping(
            direct.variation,
            [[definition(.pullUpBar, definitions)], [definition(.gymnasticRings, definitions)]],
            context
        )
        let supportMapping = VariationEquipmentMapping(variation: support.variation, kind: .baselineOnly)
        context.insert(supportMapping)

        XCTAssertEqual(
            SkillTrainabilityResolver.resolve(
                skill: skill,
                against: [],
                connections: [],
                exerciseLinks: [directLink, supportLink],
                equipmentMappings: [directMapping, supportMapping],
                profile: profile
            ),
            .temporarilyUnavailable
        )

        EquipmentAvailabilityManager.setAvailable(
            true,
            equipmentID: definition(.gymnasticRings, definitions).id,
            profile: profile
        )
        XCTAssertEqual(
            SkillTrainabilityResolver.resolve(
                skill: skill,
                against: [],
                connections: [],
                exerciseLinks: [directLink, supportLink],
                equipmentMappings: [directMapping, supportMapping],
                profile: profile
            ),
            .trainable
        )
    }

    func testDerivedTrainabilityFeedsFocusWithoutMutatingPriorityOrMastery() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let skills = (1...4).map { Skill(name: "Skill \($0)", emoji: "") }
        var links: [SkillExerciseLink] = []
        var mappings: [VariationEquipmentMapping] = []
        for index in skills.indices {
            let current = stage("Current", 0, skills[index])
            skills[index].stages = [current]
            _ = requirementVariation(for: current)
            context.insert(skills[index])
            context.insert(current)
            let direct = movement(metric: .reps)
            context.insert(direct.exercise)
            context.insert(direct.variation)
            let link = SkillExerciseLink(skill: skills[index], stage: current, variation: direct.variation, role: .direct)
            context.insert(link)
            links.append(link)
            if index == 1 {
                mappings.append(mapping(
                    direct.variation,
                    [[definition(.pullUpBar, definitions)]],
                    context
                ))
            } else {
                let mapping = VariationEquipmentMapping(variation: direct.variation, kind: .baselineOnly)
                context.insert(mapping)
                mappings.append(mapping)
            }
            SkillGoalManager.select(skill: skills[index], profile: profile, context: context)
        }
        let goals = SkillGoalManager.orderedSelectedGoals(profile.skillGoals)
        let storedPriorities = goals.map(\.priority)

        func trainability() -> [UUID: SkillTrainability] {
            Dictionary(uniqueKeysWithValues: skills.map { skill in
                (skill.id, SkillTrainabilityResolver.resolve(
                    skill: skill,
                    against: [],
                    connections: [],
                    exerciseLinks: links,
                    equipmentMappings: mappings,
                    profile: profile
                ))
            })
        }

        var focus = SkillFocusResolver.resolve(
            goals: goals,
            masteredSkillIDs: [],
            trainabilityBySkillID: trainability()
        )
        XCTAssertEqual(focus.focusGoalIDs, [goals[0].id, goals[2].id, goals[3].id])
        XCTAssertEqual(goals.map(\.priority), storedPriorities)

        EquipmentAvailabilityManager.setAvailable(
            true,
            equipmentID: definition(.pullUpBar, definitions).id,
            profile: profile
        )
        focus = SkillFocusResolver.resolve(
            goals: goals,
            masteredSkillIDs: [],
            trainabilityBySkillID: trainability()
        )
        XCTAssertEqual(focus.focusGoalIDs, [goals[0].id, goals[1].id, goals[2].id])
        XCTAssertEqual(goals.map(\.priority), storedPriorities)
    }

    func testEquipmentLossChangesAvailabilityButNotEvidenceDerivedMastery() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let bar = definition(.pullUpBar, definitions)
        let skill = Skill(name: "Mastered", emoji: "")
        let completion = stage("Completion", 0, skill, isCompletion: true)
        skill.stages = [completion]
        let variation = requirementVariation(for: completion)
        let history = [session(variation)]
        let mapping = mapping(variation, [[bar]], context)

        EquipmentAvailabilityManager.setAvailable(true, equipmentID: bar.id, profile: profile)
        XCTAssertTrue(SkillTopologyEngine.isSkillMastered(skill, against: history))
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: variation.id,
                mappings: [mapping],
                profile: profile
            ),
            .available
        )

        EquipmentAvailabilityManager.setAvailable(false, equipmentID: bar.id, profile: profile)
        XCTAssertTrue(SkillTopologyEngine.isSkillMastered(skill, against: history))
        XCTAssertEqual(
            ExerciseAvailabilityResolver.resolve(
                variationID: variation.id,
                mappings: [mapping],
                profile: profile
            ),
            .unavailable
        )
    }

    private func trainabilityFixture() throws -> (
        container: ModelContainer,
        skill: Skill,
        profile: AthleteProfile,
        links: [SkillExerciseLink],
        mappings: [VariationEquipmentMapping]
    ) {
        let container = try makeContainer()
        let context = ModelContext(container)
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<AthleteProfile>()).first)
        let definitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let skill = Skill(name: "Direct", emoji: "")
        let current = stage("Current", 0, skill)
        skill.stages = [current]
        _ = requirementVariation(for: current)
        let direct = movement(metric: .reps)
        let support = movement(metric: .reps)
        let directLink = SkillExerciseLink(skill: skill, stage: current, variation: direct.variation, role: .direct)
        let supportLink = SkillExerciseLink(skill: skill, stage: current, variation: support.variation, role: .support)
        let directMapping = VariationEquipmentMapping(variation: direct.variation, kind: .baselineOnly)
        let supportMapping = mapping(
            support.variation,
            [[definition(.pullUpBar, definitions)]],
            context
        )
        return (container, skill, profile, [directLink, supportLink], [directMapping, supportMapping])
    }

    private func statesByID(
        _ skill: Skill,
        _ sessions: [WorkoutSession],
        _ connections: [SkillStageConnection]
    ) -> [UUID: SkillNodeState] {
        Dictionary(uniqueKeysWithValues: SkillTopologyEngine.nodeStates(
            for: skill,
            against: sessions,
            connections: connections
        ).map { ($0.stageID, $0) })
    }

    private func stage(
        _ name: String,
        _ order: Int,
        _ skill: Skill,
        kind: SkillNodeKind = .primary,
        prerequisiteMode: SkillPrerequisiteMode = .all,
        isCompletion: Bool = false
    ) -> SkillStage {
        SkillStage(
            name: name,
            orderIndex: order,
            nodeKind: kind,
            prerequisiteMode: prerequisiteMode,
            isSkillCompletion: isCompletion,
            skill: skill
        )
    }

    @discardableResult
    private func requirementVariation(for stage: SkillStage) -> ExerciseVariation {
        let fixture = movement(metric: .reps)
        stage.requirements = [Requirement(
            title: "Requirement",
            exerciseID: fixture.exercise.id,
            variationID: fixture.variation.id,
            metric: .reps,
            evidenceKind: .reps,
            targetReps: 1,
            skillStage: stage
        )]
        return fixture.variation
    }

    private func movement(metric: ExerciseMetric) -> (exercise: Exercise, variation: ExerciseVariation) {
        let exercise = Exercise(name: UUID().uuidString, metric: metric)
        let variation = ExerciseVariation(name: UUID().uuidString, metric: metric, exercise: exercise)
        return (exercise, variation)
    }

    private func session(
        _ variation: ExerciseVariation,
        attempt: AttemptOutcome? = nil
    ) -> WorkoutSession {
        let session = WorkoutSession(workoutName: "Evidence")
        let log = ExerciseLog(exercise: variation.exercise!, variation: variation, orderIndex: 0, session: session)
        let set = SetLog(
            setNumber: 1,
            reps: attempt == nil ? 1 : nil,
            effortKind: attempt == nil ? .numeric : .attempt,
            attemptOutcome: attempt,
            variation: variation,
            exerciseLog: log
        )
        log.sets = [set]
        session.exerciseLogs = [log]
        return session
    }

    @discardableResult
    private func mapping(
        _ variation: ExerciseVariation,
        _ options: [[EquipmentDefinition]],
        _ context: ModelContext
    ) -> VariationEquipmentMapping {
        let mapping = VariationEquipmentMapping(variation: variation, kind: .configured)
        context.insert(mapping)
        mapping.setups = options.enumerated().map { index, definitions in
            let setup = VariationEquipmentSetup(orderIndex: index, mapping: mapping)
            context.insert(setup)
            setup.items = definitions.map { definition in
                let item = VariationEquipmentItem(equipment: definition, setup: setup)
                context.insert(item)
                return item
            }
            return setup
        }
        return mapping
    }

    private func definition(
        _ kind: EquipmentKind,
        _ definitions: [EquipmentDefinition]
    ) -> EquipmentDefinition {
        definitions.first(where: { $0.id == EquipmentCatalog.items.first(where: { $0.kind == kind })!.id })!
    }

    private func resolve(
        _ variation: ExerciseVariation,
        _ mappings: [VariationEquipmentMapping],
        _ kinds: Set<EquipmentKind>
    ) -> ExerciseAvailability {
        let ids = Set(EquipmentCatalog.items.filter { kinds.contains($0.kind) }.map(\.id))
        return ExerciseAvailabilityResolver.resolve(
            variationID: variation.id,
            mappings: mappings,
            availableEquipmentIDs: ids
        )
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
