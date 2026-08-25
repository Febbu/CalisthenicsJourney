import Foundation
import SwiftData

enum SkillNodeKind: String, Codable, CaseIterable {
    case primary
    case optional
    case safety

    var isOptional: Bool { self != .primary }
}

enum SkillPrerequisiteMode: String, Codable, CaseIterable {
    case all
    case any
}

enum SkillExerciseRole: String, Codable, CaseIterable {
    case direct
    case support
    case preparation
    case safetyPractice
}

enum EquipmentMappingKind: String, Codable, CaseIterable {
    case baselineOnly
    case configured
}

@Model
final class SkillStageConnection {
    @Attribute(.unique) var id: UUID
    var sourceStageID: UUID
    var destinationStageID: UUID
    var createdAt: Date
    var sourceStage: SkillStage?
    var destinationStage: SkillStage?

    init(source: SkillStage, destination: SkillStage) {
        self.id = UUID()
        self.sourceStageID = source.id
        self.destinationStageID = destination.id
        self.createdAt = .now
        self.sourceStage = source
        self.destinationStage = destination
    }
}

@Model
final class SkillExerciseLink {
    @Attribute(.unique) var id: UUID
    var skillID: UUID
    var stageID: UUID
    var variationID: UUID
    var roleRaw: String
    var createdAt: Date
    var stage: SkillStage?
    var variation: ExerciseVariation?

    var role: SkillExerciseRole? { SkillExerciseRole(rawValue: roleRaw) }

    init(skill: Skill, stage: SkillStage, variation: ExerciseVariation, role: SkillExerciseRole) {
        self.id = UUID()
        self.skillID = skill.id
        self.stageID = stage.id
        self.variationID = variation.id
        self.roleRaw = role.rawValue
        self.createdAt = .now
        self.stage = stage
        self.variation = variation
    }
}

@Model
final class VariationEquipmentMapping {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var variationID: UUID
    var kindRaw: String
    var createdAt: Date
    var updatedAt: Date
    var variation: ExerciseVariation?

    @Relationship(deleteRule: .cascade, inverse: \VariationEquipmentSetup.mapping)
    var setups: [VariationEquipmentSetup] = []

    var kind: EquipmentMappingKind? { EquipmentMappingKind(rawValue: kindRaw) }

    init(variation: ExerciseVariation, kind: EquipmentMappingKind) {
        self.id = UUID()
        self.variationID = variation.id
        self.kindRaw = kind.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.variation = variation
    }
}

@Model
final class VariationEquipmentSetup {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var createdAt: Date
    var mapping: VariationEquipmentMapping?

    @Relationship(deleteRule: .cascade, inverse: \VariationEquipmentItem.setup)
    var items: [VariationEquipmentItem] = []

    init(orderIndex: Int, mapping: VariationEquipmentMapping) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.createdAt = .now
        self.mapping = mapping
    }
}

@Model
final class VariationEquipmentItem {
    @Attribute(.unique) var id: UUID
    var equipmentID: UUID
    var createdAt: Date
    var equipment: EquipmentDefinition?
    var setup: VariationEquipmentSetup?

    init(equipment: EquipmentDefinition, setup: VariationEquipmentSetup) {
        self.id = UUID()
        self.equipmentID = equipment.id
        self.createdAt = .now
        self.equipment = equipment
        self.setup = setup
    }
}

enum ExerciseAvailability: Equatable {
    case available
    case unavailable
    case unknown
}

struct SkillNodeState: Equatable {
    let stageID: UUID
    let isMastered: Bool
    let isReachable: Bool
    let isOptional: Bool
    let isOnPrimaryPath: Bool
}

enum ExerciseAvailabilityResolver {
    static func resolve(
        variationID: UUID,
        mappings: [VariationEquipmentMapping],
        availableEquipmentIDs: Set<UUID>
    ) -> ExerciseAvailability {
        let matching = mappings.filter { $0.variationID == variationID }
        guard matching.count == 1, let mapping = matching.first else { return .unknown }
        guard let kind = mapping.kind else { return .unknown }

        switch kind {
        case .baselineOnly:
            return mapping.setups.isEmpty ? .available : .unknown
        case .configured:
            guard !mapping.setups.isEmpty else { return .unknown }
            var sawValidSetup = false
            for setup in mapping.setups {
                let equipmentIDs = setup.items.map(\.equipmentID)
                guard !equipmentIDs.isEmpty else { continue }
                sawValidSetup = true
                if Set(equipmentIDs).isSubset(of: availableEquipmentIDs) {
                    return .available
                }
            }
            return sawValidSetup ? .unavailable : .unknown
        }
    }

    static func resolve(
        variationID: UUID,
        mappings: [VariationEquipmentMapping],
        profile: AthleteProfile
    ) -> ExerciseAvailability {
        resolve(
            variationID: variationID,
            mappings: mappings,
            availableEquipmentIDs: Set(
                profile.equipmentAvailability.filter(\.isAvailable).map(\.equipmentID)
            )
        )
    }
}

enum SkillTopologyEngine {
    static func nodeStates(
        for skill: Skill,
        against sessions: [WorkoutSession],
        connections: [SkillStageConnection],
        implications: [RequirementImplication] = []
    ) -> [SkillNodeState] {
        let stages = skill.stages.sorted {
            if $0.orderIndex == $1.orderIndex { return $0.id.uuidString < $1.id.uuidString }
            return $0.orderIndex < $1.orderIndex
        }
        let stageIDs = Set(stages.map(\.id))
        let masteredIDs = Set(stages.filter {
            ProgressionEngine.isMastered($0, against: sessions, implications: implications)
        }.map(\.id))
        let validConnections = connections.filter {
            stageIDs.contains($0.sourceStageID) && stageIDs.contains($0.destinationStageID)
        }

        return stages.map { stage in
            let incoming = validConnections.filter { $0.destinationStageID == stage.id }
            let reachable: Bool
            if incoming.isEmpty {
                reachable = true
            } else if let mode = stage.prerequisiteMode {
                switch mode {
                case .all:
                    reachable = incoming.allSatisfy { masteredIDs.contains($0.sourceStageID) }
                case .any:
                    reachable = incoming.contains { masteredIDs.contains($0.sourceStageID) }
                }
            } else {
                reachable = false
            }
            let kind = stage.nodeKind
            return SkillNodeState(
                stageID: stage.id,
                isMastered: masteredIDs.contains(stage.id),
                isReachable: reachable,
                isOptional: kind?.isOptional ?? false,
                isOnPrimaryPath: kind == .primary
            )
        }
    }

    static func isSkillMastered(
        _ skill: Skill,
        against sessions: [WorkoutSession],
        implications: [RequirementImplication] = []
    ) -> Bool {
        let completionStages = skill.stages.filter { $0.isSkillCompletion && $0.nodeKind == .primary }
        return !completionStages.isEmpty && completionStages.contains {
            ProgressionEngine.isMastered($0, against: sessions, implications: implications)
        }
    }
}

enum SkillTrainabilityResolver {
    static func resolve(
        skill: Skill,
        against sessions: [WorkoutSession],
        connections: [SkillStageConnection],
        exerciseLinks: [SkillExerciseLink],
        equipmentMappings: [VariationEquipmentMapping],
        profile: AthleteProfile,
        implications: [RequirementImplication] = []
    ) -> SkillTrainability {
        let states = SkillTopologyEngine.nodeStates(
            for: skill,
            against: sessions,
            connections: connections,
            implications: implications
        )
        let relevantStageIDs = Set(states.filter {
            $0.isOnPrimaryPath && $0.isReachable && !$0.isMastered
        }.map(\.stageID))
        guard !relevantStageIDs.isEmpty else { return .unknown }

        let directLinks = exerciseLinks.filter {
            $0.skillID == skill.id
                && relevantStageIDs.contains($0.stageID)
                && $0.role == .direct
        }
        guard !directLinks.isEmpty else { return .unknown }

        let availability = directLinks.map {
            ExerciseAvailabilityResolver.resolve(
                variationID: $0.variationID,
                mappings: equipmentMappings,
                profile: profile
            )
        }
        if availability.contains(.available) { return .trainable }
        if availability.allSatisfy({ $0 == .unavailable }) { return .temporarilyUnavailable }
        return .unknown
    }
}
