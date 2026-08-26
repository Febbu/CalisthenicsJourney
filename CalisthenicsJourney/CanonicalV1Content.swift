import Foundation
import SwiftData

enum CanonicalV1ContentError: Error, Equatable {
    case invalidTopology(skillID: UUID, issues: [SkillTopologyValidationIssue])
}

@MainActor
enum CanonicalV1Content {
    static let skillKeys = [
        "push-up", "pull-up", "dip", "handstand", "l-sit", "pistol-squat",
        "muscle-up", "front-lever", "planche"
    ]

    static let skillNames = [
        "Push-up", "Pull-up", "Dip", "Handstand", "L-Sit", "Pistol Squat",
        "Muscle-up", "Front Lever", "Planche"
    ]

    static func id(for key: String) -> UUID {
        var first: UInt64 = 0xcbf29ce484222325
        var second: UInt64 = 0x84222325cbf29ce4
        for byte in "calisthenics-journey-v1:\(key)".utf8 {
            first = (first ^ UInt64(byte)) &* 0x100000001b3
            second = (second ^ UInt64(byte)) &* 0x100000001b3
            second ^= first >> 32
        }
        var bytes = withUnsafeBytes(of: first.bigEndian, Array.init)
        bytes.append(contentsOf: withUnsafeBytes(of: second.bigEndian, Array.init))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func installIfNeeded(context: ModelContext) throws {
        let existingSkills = try context.fetch(FetchDescriptor<Skill>())
        let canonicalSkillIDs = Set(skillKeys.map { id(for: "skill.\($0)") })
        guard !canonicalSkillIDs.isSubset(of: Set(existingSkills.map(\.id))) else { return }

        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        let existingVariations = try context.fetch(FetchDescriptor<ExerciseVariation>())
        let equipment = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        let equipmentByKind = Dictionary(uniqueKeysWithValues: equipment.compactMap { definition in
            definition.kind.map { ($0, definition) }
        })
        var exercisesByKey: [String: Exercise] = [:]
        var variationsByKey: [String: ExerciseVariation] = [:]
        let exercisesByID = Dictionary(uniqueKeysWithValues: existingExercises.map { ($0.id, $0) })
        let variationsByID = Dictionary(uniqueKeysWithValues: existingVariations.map { ($0.id, $0) })

        for spec in exerciseSpecs {
            let exerciseID = id(for: "exercise.\(spec.key)")
            if let existing = exercisesByID[exerciseID] {
                exercisesByKey[spec.key] = existing
            } else {
                let exercise = Exercise(name: spec.name, metric: spec.metric)
                exercise.id = exerciseID
                context.insert(exercise)
                exercisesByKey[spec.key] = exercise
            }
        }

        for spec in variationSpecs {
            let variationID = id(for: "variation.\(spec.key)")
            if let existing = variationsByID[variationID] {
                variationsByKey[spec.key] = existing
                continue
            }
            guard let exercise = exercisesByKey[spec.exerciseKey] else { continue }
            let variation = ExerciseVariation(name: spec.name, metric: spec.metric, exercise: exercise)
            variation.id = variationID
            context.insert(variation)
            exercise.variations.append(variation)
            variationsByKey[spec.key] = variation
        }

        let currentSkillsByID = Dictionary(uniqueKeysWithValues: existingSkills.map { ($0.id, $0) })
        var newlySeeded: [(Skill, Set<UUID>)] = []
        for skillSpec in skillSpecs {
            let skillID = id(for: "skill.\(skillSpec.key)")
            guard currentSkillsByID[skillID] == nil else { continue }

            let skill = Skill(name: skillSpec.name, emoji: skillSpec.emoji)
            skill.id = skillID
            context.insert(skill)
            var stagesByKey: [String: SkillStage] = [:]

            for (index, stageSpec) in skillSpec.stages.enumerated() {
                let stage = SkillStage(
                    name: stageSpec.name,
                    orderIndex: index,
                    nodeKind: stageSpec.kind,
                    isSkillCompletion: stageSpec.isCompletion,
                    skill: skill
                )
                stage.id = id(for: "stage.\(skillSpec.key).\(stageSpec.key)")
                context.insert(stage)
                skill.stages.append(stage)
                stagesByKey[stageSpec.key] = stage

                for (requirementIndex, requirementSpec) in stageSpec.requirements.enumerated() {
                    guard let variation = variationsByKey[requirementSpec.variationKey] else { continue }
                    let requirement = Requirement(
                        id: id(for: "requirement.\(skillSpec.key).\(stageSpec.key).\(requirementIndex)"),
                        title: requirementSpec.title,
                        exerciseID: variation.exercise?.id,
                        variationID: variation.id,
                        metric: requirementSpec.metric,
                        evidenceKind: requirementSpec.evidenceKind,
                        side: requirementSpec.side,
                        targetReps: requirementSpec.targetReps,
                        targetSeconds: requirementSpec.targetSeconds,
                        confirmationsNeeded: 1,
                        skillStage: stage
                    )
                    context.insert(requirement)
                    stage.requirements.append(requirement)
                }

                var links = stageSpec.requirements.map {
                    LinkSpec(variationKey: $0.variationKey, role: stageSpec.kind == .safety ? .safetyPractice : .direct)
                }
                links.append(contentsOf: stageSpec.additionalLinks)
                var seenLinks = Set<String>()
                for linkSpec in links where seenLinks.insert("\(linkSpec.variationKey):\(linkSpec.role.rawValue)").inserted {
                    guard let variation = variationsByKey[linkSpec.variationKey] else { continue }
                    let link = SkillExerciseLink(
                        skill: skill,
                        stage: stage,
                        variation: variation,
                        role: linkSpec.role
                    )
                    link.id = id(for: "link.\(skillSpec.key).\(stageSpec.key).\(linkSpec.variationKey).\(linkSpec.role.rawValue)")
                    context.insert(link)
                }
            }

            for edge in skillSpec.edges {
                guard let source = stagesByKey[edge.0], let destination = stagesByKey[edge.1] else { continue }
                let connection = SkillStageConnection(source: source, destination: destination)
                connection.id = id(for: "connection.\(skillSpec.key).\(edge.0).\(edge.1)")
                context.insert(connection)
            }

            let roots = Set(skillSpec.rootKeys.compactMap { stagesByKey[$0]?.id })
            newlySeeded.append((skill, roots))
        }

        try installEquipmentMappings(
            context: context,
            variationsByKey: variationsByKey,
            equipmentByKind: equipmentByKind
        )

        let allStages = try context.fetch(FetchDescriptor<SkillStage>())
        let allConnections = try context.fetch(FetchDescriptor<SkillStageConnection>())
        for (skill, roots) in newlySeeded {
            let stageIDs = Set(skill.stages.map(\.id))
            let localConnections = allConnections.filter {
                stageIDs.contains($0.sourceStageID) || stageIDs.contains($0.destinationStageID)
            }
            let result = SkillTopologyValidator.validate(
                skill: skill,
                allStages: allStages,
                connections: localConnections,
                intendedRootStageIDs: roots
            )
            guard result.isValid else {
                throw CanonicalV1ContentError.invalidTopology(skillID: skill.id, issues: result.issues)
            }
        }
    }

    private static func installEquipmentMappings(
        context: ModelContext,
        variationsByKey: [String: ExerciseVariation],
        equipmentByKind: [EquipmentKind: EquipmentDefinition]
    ) throws {
        let existing = try context.fetch(FetchDescriptor<VariationEquipmentMapping>())
        let existingVariationIDs = Set(existing.map(\.variationID))
        for spec in equipmentSpecs {
            guard let variation = variationsByKey[spec.variationKey],
                  !existingVariationIDs.contains(variation.id) else { continue }
            let mapping = VariationEquipmentMapping(variation: variation, kind: spec.kind)
            mapping.id = id(for: "equipment-mapping.\(spec.variationKey)")
            context.insert(mapping)
            for (setupIndex, setupKinds) in spec.setups.enumerated() {
                let setup = VariationEquipmentSetup(orderIndex: setupIndex, mapping: mapping)
                setup.id = id(for: "equipment-setup.\(spec.variationKey).\(setupIndex)")
                context.insert(setup)
                mapping.setups.append(setup)
                for kind in setupKinds {
                    guard let definition = equipmentByKind[kind] else { continue }
                    let item = VariationEquipmentItem(equipment: definition, setup: setup)
                    item.id = id(for: "equipment-item.\(spec.variationKey).\(setupIndex).\(kind.rawValue)")
                    context.insert(item)
                    setup.items.append(item)
                }
            }
        }
    }
}

private extension CanonicalV1Content {
    struct ExerciseSpec {
        let key: String
        let name: String
        let metric: ExerciseMetric
    }

    struct VariationSpec {
        let key: String
        let exerciseKey: String
        let name: String
        let metric: ExerciseMetric
    }

    struct RequirementSpec {
        let title: String
        let variationKey: String
        let metric: RequirementMetric
        let evidenceKind: RequirementEvidenceKind
        let side: PerformanceSide
        let targetReps: Int?
        let targetSeconds: Int?

        static func reps(_ title: String, _ variation: String, _ target: Int, side: PerformanceSide = .notApplicable) -> Self {
            Self(title: title, variationKey: variation, metric: .reps, evidenceKind: .reps, side: side, targetReps: target, targetSeconds: nil)
        }

        static func seconds(_ title: String, _ variation: String, _ target: Int, side: PerformanceSide = .notApplicable) -> Self {
            Self(title: title, variationKey: variation, metric: .seconds, evidenceKind: .seconds, side: side, targetReps: nil, targetSeconds: target)
        }

        static func successful(_ title: String, _ variation: String, side: PerformanceSide = .notApplicable) -> Self {
            Self(title: title, variationKey: variation, metric: .reps, evidenceKind: .successfulAttempt, side: side, targetReps: nil, targetSeconds: nil)
        }
    }

    struct LinkSpec {
        let variationKey: String
        let role: SkillExerciseRole

        static func support(_ variation: String) -> Self { Self(variationKey: variation, role: .support) }
        static func safety(_ variation: String) -> Self { Self(variationKey: variation, role: .safetyPractice) }
    }

    struct StageSpec {
        let key: String
        let name: String
        let kind: SkillNodeKind
        let isCompletion: Bool
        let requirements: [RequirementSpec]
        let additionalLinks: [LinkSpec]

        init(
            _ key: String,
            _ name: String,
            kind: SkillNodeKind = .primary,
            completion: Bool = false,
            requirements: [RequirementSpec],
            links: [LinkSpec] = []
        ) {
            self.key = key
            self.name = name
            self.kind = kind
            self.isCompletion = completion
            self.requirements = requirements
            self.additionalLinks = links
        }
    }

    struct SkillSpec {
        let key: String
        let name: String
        let emoji: String
        let stages: [StageSpec]
        let edges: [(String, String)]
        let rootKeys: [String]

        init(key: String, name: String, emoji: String, stages: [StageSpec], edges: [(String, String)]? = nil, rootKeys: [String]? = nil) {
            self.key = key
            self.name = name
            self.emoji = emoji
            self.stages = stages
            self.edges = edges ?? zip(stages, stages.dropFirst()).map { ($0.key, $1.key) }
            self.rootKeys = rootKeys ?? stages.first.map { [$0.key] } ?? []
        }
    }

    struct EquipmentSpec {
        let variationKey: String
        let kind: EquipmentMappingKind
        let setups: [[EquipmentKind]]

        static func baseline(_ variation: String) -> Self {
            Self(variationKey: variation, kind: .baselineOnly, setups: [])
        }

        static func configured(_ variation: String, _ setups: [[EquipmentKind]]) -> Self {
            Self(variationKey: variation, kind: .configured, setups: setups)
        }
    }

    static let exerciseSpecs: [ExerciseSpec] = [
        .init(key: "push-up", name: "Push-up", metric: .reps),
        .init(key: "pull-up", name: "Pull-up", metric: .reps),
        .init(key: "dip", name: "Dip", metric: .reps),
        .init(key: "l-sit", name: "L-Sit", metric: .seconds),
        .init(key: "pistol-squat", name: "Pistol Squat", metric: .reps),
        .init(key: "handstand", name: "Handstand", metric: .seconds),
        .init(key: "muscle-up", name: "Bar Muscle-up", metric: .reps),
        .init(key: "front-lever", name: "Front Lever", metric: .seconds),
        .init(key: "planche", name: "Planche", metric: .seconds)
    ]

    static let variationSpecs: [VariationSpec] = [
        .init(key: "wall-push-up", exerciseKey: "push-up", name: "Wall Push-up", metric: .reps),
        .init(key: "incline-push-up", exerciseKey: "push-up", name: "Incline Push-up", metric: .reps),
        .init(key: "knee-push-up", exerciseKey: "push-up", name: "Knee Push-up", metric: .reps),
        .init(key: "strict-push-up", exerciseKey: "push-up", name: "Strict Push-up", metric: .reps),
        .init(key: "dead-hang", exerciseKey: "pull-up", name: "Dead Hang", metric: .seconds),
        .init(key: "scapular-pull", exerciseKey: "pull-up", name: "Active Hang / Scapular Pull", metric: .reps),
        .init(key: "assisted-pull-up", exerciseKey: "pull-up", name: "Assisted Pull-up", metric: .reps),
        .init(key: "negative-pull-up", exerciseKey: "pull-up", name: "Negative Pull-up", metric: .reps),
        .init(key: "strict-pull-up", exerciseKey: "pull-up", name: "Strict Pull-up", metric: .reps),
        .init(key: "parallel-bar-support", exerciseKey: "dip", name: "Parallel Bar Support Hold", metric: .seconds),
        .init(key: "assisted-dip", exerciseKey: "dip", name: "Assisted Dip", metric: .reps),
        .init(key: "negative-dip", exerciseKey: "dip", name: "Negative Dip", metric: .reps),
        .init(key: "strict-dip", exerciseKey: "dip", name: "Strict Dip", metric: .reps),
        .init(key: "supported-l-sit-press", exerciseKey: "l-sit", name: "Supported L-Sit Press", metric: .reps),
        .init(key: "single-leg-lift", exerciseKey: "l-sit", name: "Single-Leg Lift", metric: .reps),
        .init(key: "seated-leg-raise", exerciseKey: "l-sit", name: "Seated Leg Raises", metric: .reps),
        .init(key: "tuck-l-sit", exerciseKey: "l-sit", name: "Tuck L-Sit", metric: .seconds),
        .init(key: "one-leg-l-sit", exerciseKey: "l-sit", name: "One-Leg L-Sit", metric: .seconds),
        .init(key: "full-l-sit", exerciseKey: "l-sit", name: "Full L-Sit", metric: .seconds),
        .init(key: "deep-bodyweight-squat", exerciseKey: "pistol-squat", name: "Deep Bodyweight Squat", metric: .reps),
        .init(key: "assisted-pistol", exerciseKey: "pistol-squat", name: "Assisted Pistol Squat", metric: .reps),
        .init(key: "negative-pistol", exerciseKey: "pistol-squat", name: "Negative Pistol Squat", metric: .reps),
        .init(key: "pistol-squat", exerciseKey: "pistol-squat", name: "Pistol Squat", metric: .reps),
        .init(key: "wall-walk", exerciseKey: "handstand", name: "Wall Walk", metric: .reps),
        .init(key: "chest-to-wall-handstand", exerciseKey: "handstand", name: "Chest-to-Wall Handstand", metric: .seconds),
        .init(key: "safe-handstand-bail", exerciseKey: "handstand", name: "Safe Handstand Bail", metric: .reps),
        .init(key: "wall-handstand-balance", exerciseKey: "handstand", name: "Wall Handstand Balance", metric: .reps),
        .init(key: "controlled-kick-up", exerciseKey: "handstand", name: "Controlled Handstand Kick-Up", metric: .reps),
        .init(key: "freestanding-handstand", exerciseKey: "handstand", name: "Freestanding Handstand", metric: .seconds),
        .init(key: "high-pull-up", exerciseKey: "muscle-up", name: "High Pull-up", metric: .reps),
        .init(key: "straight-bar-dip", exerciseKey: "muscle-up", name: "Straight-Bar Dip", metric: .reps),
        .init(key: "assisted-muscle-up", exerciseKey: "muscle-up", name: "Assisted Bar Muscle-up", metric: .reps),
        .init(key: "muscle-up-transition", exerciseKey: "muscle-up", name: "Muscle-up Transition", metric: .reps),
        .init(key: "negative-muscle-up", exerciseKey: "muscle-up", name: "Negative Bar Muscle-up", metric: .reps),
        .init(key: "strict-muscle-up", exerciseKey: "muscle-up", name: "Strict Bar Muscle-up", metric: .reps),
        .init(key: "tuck-front-lever", exerciseKey: "front-lever", name: "Tuck Front Lever", metric: .seconds),
        .init(key: "advanced-tuck-front-lever", exerciseKey: "front-lever", name: "Advanced Tuck Front Lever", metric: .seconds),
        .init(key: "one-leg-front-lever", exerciseKey: "front-lever", name: "One-Leg Front Lever", metric: .seconds),
        .init(key: "straddle-front-lever", exerciseKey: "front-lever", name: "Straddle Front Lever", metric: .seconds),
        .init(key: "full-front-lever", exerciseKey: "front-lever", name: "Full Front Lever", metric: .seconds),
        .init(key: "planche-lean", exerciseKey: "planche", name: "Planche Lean", metric: .seconds),
        .init(key: "frog-stand", exerciseKey: "planche", name: "Frog Stand", metric: .seconds),
        .init(key: "tuck-planche", exerciseKey: "planche", name: "Tuck Planche", metric: .seconds),
        .init(key: "advanced-tuck-planche", exerciseKey: "planche", name: "Advanced Tuck Planche", metric: .seconds),
        .init(key: "one-leg-planche", exerciseKey: "planche", name: "One-Leg Planche", metric: .seconds),
        .init(key: "straddle-planche", exerciseKey: "planche", name: "Straddle Planche", metric: .seconds),
        .init(key: "full-planche", exerciseKey: "planche", name: "Full Planche", metric: .seconds)
    ]

    static let skillSpecs: [SkillSpec] = [
        SkillSpec(key: "push-up", name: "Push-up", emoji: "💪", stages: [
            StageSpec("wall", "Wall Push-up", requirements: [.successful("Demonstrate a Wall Push-up", "wall-push-up")]),
            StageSpec("incline", "Incline Push-up", requirements: [.successful("Demonstrate an Incline Push-up", "incline-push-up")], links: [.support("wall-push-up")]),
            StageSpec("knee", "Knee Push-up", requirements: [.successful("Demonstrate a Knee Push-up", "knee-push-up")], links: [.support("incline-push-up")]),
            StageSpec("strict-1", "1 Strict Push-up", requirements: [.reps("1 Strict Push-up", "strict-push-up", 1)], links: [.support("incline-push-up"), .support("knee-push-up")]),
            StageSpec("strict-5", "5 Strict Push-ups", requirements: [.reps("5 Strict Push-ups", "strict-push-up", 5)]),
            StageSpec("strict-10", "10 Strict Push-ups", completion: true, requirements: [.reps("10 Strict Push-ups", "strict-push-up", 10)])
        ]),
        SkillSpec(key: "pull-up", name: "Pull-up", emoji: "🪽", stages: [
            StageSpec("dead-hang", "Dead Hang", requirements: [.successful("Demonstrate a Dead Hang", "dead-hang")]),
            StageSpec("active-hang", "Active Hang / Scapular Pull", requirements: [.successful("Demonstrate an Active Hang / Scapular Pull", "scapular-pull")], links: [.support("dead-hang")]),
            StageSpec("assisted", "Assisted Pull-up", requirements: [.successful("Demonstrate an Assisted Pull-up", "assisted-pull-up")], links: [.support("scapular-pull")]),
            StageSpec("negative", "Negative Pull-up", requirements: [.successful("Demonstrate a Negative Pull-up", "negative-pull-up")], links: [.support("assisted-pull-up")]),
            StageSpec("strict-1", "1 Strict Pull-up", requirements: [.reps("1 Strict Pull-up", "strict-pull-up", 1)], links: [.support("negative-pull-up"), .support("assisted-pull-up")]),
            StageSpec("strict-3", "3 Strict Pull-ups", requirements: [.reps("3 Strict Pull-ups", "strict-pull-up", 3)], links: [.support("assisted-pull-up")]),
            StageSpec("strict-5", "5 Strict Pull-ups", completion: true, requirements: [.reps("5 Strict Pull-ups", "strict-pull-up", 5)])
        ]),
        SkillSpec(key: "dip", name: "Dip", emoji: "💪", stages: [
            StageSpec("support", "Parallel Bar Support Hold", requirements: [.successful("Demonstrate a Parallel Bar Support Hold", "parallel-bar-support")]),
            StageSpec("assisted", "Assisted Dip", requirements: [.successful("Demonstrate an Assisted Dip", "assisted-dip")], links: [.support("parallel-bar-support")]),
            StageSpec("negative", "Negative Dip", requirements: [.successful("Demonstrate a Negative Dip", "negative-dip")], links: [.support("assisted-dip")]),
            StageSpec("strict-1", "1 Strict Dip", requirements: [.reps("1 Strict Dip", "strict-dip", 1)], links: [.support("negative-dip"), .support("assisted-dip")]),
            StageSpec("strict-3", "3 Strict Dips", requirements: [.reps("3 Strict Dips", "strict-dip", 3)], links: [.support("assisted-dip")]),
            StageSpec("strict-5", "5 Strict Dips", completion: true, requirements: [.reps("5 Strict Dips", "strict-dip", 5)])
        ]),
        SkillSpec(key: "l-sit", name: "L-Sit", emoji: "🧘", stages: [
            StageSpec("supported-press", "Supported L-Sit Press", requirements: [.successful("Demonstrate a Supported L-Sit Press", "supported-l-sit-press")]),
            StageSpec("single-leg-lift", "Single-Leg Lift", requirements: [.successful("Demonstrate a Single-Leg Lift", "single-leg-lift")], links: [.support("supported-l-sit-press")]),
            StageSpec("seated-leg-raises", "Seated Leg Raises", requirements: [.successful("Demonstrate Seated Leg Raises", "seated-leg-raise")], links: [.support("single-leg-lift")]),
            StageSpec("tuck", "Tuck L-Sit", requirements: [.successful("Demonstrate a Tuck L-Sit", "tuck-l-sit")], links: [.support("seated-leg-raise")]),
            StageSpec("one-leg", "One-Leg L-Sit (both sides)", requirements: [
                .successful("Demonstrate a Left One-Leg L-Sit", "one-leg-l-sit", side: .left),
                .successful("Demonstrate a Right One-Leg L-Sit", "one-leg-l-sit", side: .right)
            ], links: [.support("tuck-l-sit")]),
            StageSpec("full-first", "First Full L-Sit", requirements: [.successful("Demonstrate a Full L-Sit", "full-l-sit")], links: [.support("one-leg-l-sit"), .support("tuck-l-sit")]),
            StageSpec("full-10", "10s Full L-Sit", completion: true, requirements: [.seconds("10s Full L-Sit", "full-l-sit", 10)])
        ]),
        SkillSpec(key: "pistol-squat", name: "Pistol Squat", emoji: "🦵", stages: [
            StageSpec("deep-squat", "Deep Bodyweight Squat", requirements: [.successful("Demonstrate a Deep Bodyweight Squat", "deep-bodyweight-squat")]),
            StageSpec("assisted", "Assisted Pistol Squat", requirements: [.successful("Demonstrate an Assisted Pistol Squat", "assisted-pistol")], links: [.support("deep-bodyweight-squat")]),
            StageSpec("negative", "Negative Pistol Squat", requirements: [.successful("Demonstrate a Negative Pistol Squat", "negative-pistol")], links: [.support("assisted-pistol")]),
            StageSpec("full-1", "1 Pistol Squat / each leg", requirements: [
                .reps("1 Left Pistol Squat", "pistol-squat", 1, side: .left),
                .reps("1 Right Pistol Squat", "pistol-squat", 1, side: .right)
            ], links: [.support("negative-pistol"), .support("assisted-pistol")]),
            StageSpec("full-3", "3 Pistol Squats / each leg", requirements: [
                .reps("3 Left Pistol Squats", "pistol-squat", 3, side: .left),
                .reps("3 Right Pistol Squats", "pistol-squat", 3, side: .right)
            ], links: [.support("assisted-pistol")]),
            StageSpec("full-5", "5 Pistol Squats / each leg", completion: true, requirements: [
                .reps("5 Left Pistol Squats", "pistol-squat", 5, side: .left),
                .reps("5 Right Pistol Squats", "pistol-squat", 5, side: .right)
            ])
        ]),
        SkillSpec(
            key: "handstand", name: "Handstand", emoji: "🤸", stages: [
                StageSpec("wall-walk", "Wall Walk", requirements: [.successful("Demonstrate a Wall Walk", "wall-walk")]),
                StageSpec("chest-wall-30", "30s Chest-to-Wall Handstand", requirements: [.seconds("30s Chest-to-Wall Handstand", "chest-to-wall-handstand", 30)], links: [.support("wall-walk")]),
                StageSpec("safe-bail", "Safe Handstand Bail", kind: .safety, requirements: [.successful("Demonstrate a Safe Handstand Bail", "safe-handstand-bail")], links: [.support("chest-to-wall-handstand")]),
                StageSpec("wall-balance", "Wall Handstand Balance", requirements: [.successful("Demonstrate Wall Handstand Balance", "wall-handstand-balance")], links: [.support("chest-to-wall-handstand"), .safety("safe-handstand-bail")]),
                StageSpec("kick-up", "Controlled Handstand Kick-Up", requirements: [.successful("Demonstrate a Controlled Handstand Kick-Up", "controlled-kick-up")], links: [.support("wall-handstand-balance")]),
                StageSpec("freestanding-first", "First Freestanding Handstand", requirements: [.successful("Demonstrate a Freestanding Handstand", "freestanding-handstand")], links: [.support("controlled-kick-up"), .support("wall-handstand-balance")]),
                StageSpec("freestanding-5", "5s Freestanding Handstand", requirements: [.seconds("5s Freestanding Handstand", "freestanding-handstand", 5)]),
                StageSpec("freestanding-10", "10s Freestanding Handstand", completion: true, requirements: [.seconds("10s Freestanding Handstand", "freestanding-handstand", 10)])
            ],
            edges: [
                ("wall-walk", "chest-wall-30"), ("chest-wall-30", "safe-bail"),
                ("chest-wall-30", "wall-balance"), ("wall-balance", "kick-up"),
                ("kick-up", "freestanding-first"), ("freestanding-first", "freestanding-5"),
                ("freestanding-5", "freestanding-10")
            ]
        ),
        SkillSpec(key: "muscle-up", name: "Muscle-up", emoji: "🚀", stages: [
            StageSpec("foundations", "Pull-up and Dip Foundations", requirements: [
                .reps("5 Strict Pull-ups", "strict-pull-up", 5),
                .reps("5 Strict Dips", "strict-dip", 5)
            ]),
            StageSpec("high-pull", "High Pull-up", requirements: [.successful("Demonstrate a High Pull-up", "high-pull-up")], links: [.support("strict-pull-up")]),
            StageSpec("straight-bar-dip", "Straight-Bar Dip", requirements: [.successful("Demonstrate a Straight-Bar Dip", "straight-bar-dip")], links: [.support("strict-dip")]),
            StageSpec("assisted", "Assisted Muscle-up", requirements: [.successful("Demonstrate an Assisted Bar Muscle-up", "assisted-muscle-up")], links: [.support("high-pull-up"), .support("straight-bar-dip")]),
            StageSpec("transition", "Muscle-up Transition", requirements: [.successful("Demonstrate a Muscle-up Transition", "muscle-up-transition")], links: [.support("assisted-muscle-up")]),
            StageSpec("negative", "Negative Muscle-up", requirements: [.successful("Demonstrate a Negative Bar Muscle-up", "negative-muscle-up")], links: [.support("muscle-up-transition")]),
            StageSpec("strict-1", "1 Strict Bar Muscle-up", requirements: [.reps("1 Strict Bar Muscle-up", "strict-muscle-up", 1)], links: [.support("negative-muscle-up"), .support("assisted-muscle-up")]),
            StageSpec("strict-3", "3 Strict Bar Muscle-ups", completion: true, requirements: [.reps("3 Strict Bar Muscle-ups", "strict-muscle-up", 3)])
        ]),
        SkillSpec(key: "front-lever", name: "Front Lever", emoji: "↔️", stages: [
            StageSpec("foundation", "Pull-up Foundation", requirements: [.reps("5 Strict Pull-ups", "strict-pull-up", 5)]),
            StageSpec("tuck", "Tuck Front Lever", requirements: [.successful("Demonstrate a Tuck Front Lever", "tuck-front-lever")], links: [.support("strict-pull-up"), .support("scapular-pull")]),
            StageSpec("advanced-tuck", "Advanced Tuck Front Lever", requirements: [.successful("Demonstrate an Advanced Tuck Front Lever", "advanced-tuck-front-lever")], links: [.support("tuck-front-lever")]),
            StageSpec("one-leg", "One-Leg Front Lever (both sides)", requirements: [
                .successful("Demonstrate a Left One-Leg Front Lever", "one-leg-front-lever", side: .left),
                .successful("Demonstrate a Right One-Leg Front Lever", "one-leg-front-lever", side: .right)
            ], links: [.support("advanced-tuck-front-lever")]),
            StageSpec("straddle", "Straddle Front Lever", requirements: [.successful("Demonstrate a Straddle Front Lever", "straddle-front-lever")], links: [.support("one-leg-front-lever")]),
            StageSpec("full-first", "Full Front Lever", requirements: [.successful("Demonstrate a Full Front Lever", "full-front-lever")], links: [.support("straddle-front-lever")]),
            StageSpec("full-5", "5s Full Front Lever", completion: true, requirements: [.seconds("5s Full Front Lever", "full-front-lever", 5)])
        ]),
        SkillSpec(key: "planche", name: "Planche", emoji: "↔️", stages: [
            StageSpec("foundation", "Push-up Foundation", requirements: [.reps("10 Strict Push-ups", "strict-push-up", 10)]),
            StageSpec("lean", "Planche Lean", requirements: [.successful("Demonstrate a Planche Lean", "planche-lean")], links: [.support("strict-push-up")]),
            StageSpec("frog", "Frog Stand", requirements: [.successful("Demonstrate a Frog Stand", "frog-stand")], links: [.support("planche-lean")]),
            StageSpec("tuck", "Tuck Planche", requirements: [.successful("Demonstrate a Tuck Planche", "tuck-planche")], links: [.support("frog-stand"), .support("planche-lean")]),
            StageSpec("advanced-tuck", "Advanced Tuck Planche", requirements: [.successful("Demonstrate an Advanced Tuck Planche", "advanced-tuck-planche")], links: [.support("tuck-planche"), .support("planche-lean")]),
            StageSpec("one-leg", "One-Leg Planche (both sides)", requirements: [
                .successful("Demonstrate a Left One-Leg Planche", "one-leg-planche", side: .left),
                .successful("Demonstrate a Right One-Leg Planche", "one-leg-planche", side: .right)
            ], links: [.support("advanced-tuck-planche")]),
            StageSpec("straddle", "Straddle Planche", requirements: [.successful("Demonstrate a Straddle Planche", "straddle-planche")], links: [.support("one-leg-planche")]),
            StageSpec("full-first", "Full Planche", requirements: [.successful("Demonstrate a Full Planche", "full-planche")], links: [.support("straddle-planche")]),
            StageSpec("full-5", "5s Full Planche", completion: true, requirements: [.seconds("5s Full Planche", "full-planche", 5)])
        ])
    ]

    static let equipmentSpecs: [EquipmentSpec] = [
        .baseline("wall-push-up"), .baseline("knee-push-up"), .baseline("strict-push-up"),
        .configured("dead-hang", [[.pullUpBar]]), .configured("scapular-pull", [[.pullUpBar]]),
        .configured("negative-pull-up", [[.pullUpBar]]), .configured("strict-pull-up", [[.pullUpBar]]),
        .configured("parallel-bar-support", [[.dipBars]]), .configured("negative-dip", [[.dipBars]]),
        .configured("strict-dip", [[.dipBars]]), .baseline("seated-leg-raise"),
        .baseline("deep-bodyweight-squat"), .baseline("negative-pistol"), .baseline("pistol-squat"),
        .baseline("wall-walk"), .baseline("chest-to-wall-handstand"),
        .baseline("safe-handstand-bail"), .baseline("wall-handstand-balance"),
        .baseline("controlled-kick-up"), .baseline("freestanding-handstand"),
        .configured("high-pull-up", [[.pullUpBar]]), .configured("straight-bar-dip", [[.pullUpBar]]),
        .configured("muscle-up-transition", [[.pullUpBar]]), .configured("negative-muscle-up", [[.pullUpBar]]),
        .configured("strict-muscle-up", [[.pullUpBar]]),
        .configured("tuck-front-lever", [[.pullUpBar]]),
        .configured("advanced-tuck-front-lever", [[.pullUpBar]]),
        .configured("one-leg-front-lever", [[.pullUpBar]]),
        .configured("straddle-front-lever", [[.pullUpBar]]),
        .configured("full-front-lever", [[.pullUpBar]]),
        .baseline("planche-lean"), .baseline("frog-stand"), .baseline("tuck-planche"),
        .baseline("advanced-tuck-planche"), .baseline("one-leg-planche"),
        .baseline("straddle-planche"), .baseline("full-planche")
    ]
}
