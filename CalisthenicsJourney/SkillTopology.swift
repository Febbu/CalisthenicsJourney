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

enum SkillTopologyValidationIssue: Equatable {
    case stageOutsideSkill(stageID: UUID)
    case invalidNodeKind(stageID: UUID)
    case invalidPrerequisiteMode(stageID: UUID)
    case missingRequirements(stageID: UUID)
    case nonPrimaryCompletion(stageID: UUID)
    case missingPrimaryCompletion
    case danglingSource(connectionID: UUID, stageID: UUID)
    case danglingDestination(connectionID: UUID, stageID: UUID)
    case crossSkillConnection(connectionID: UUID)
    case inconsistentSourceRelationship(connectionID: UUID)
    case inconsistentDestinationRelationship(connectionID: UUID)
    case selfConnection(connectionID: UUID, stageID: UUID)
    case cycleDetected
    case unknownIntendedRoot(stageID: UUID)
    case unexpectedRoot(stageID: UUID)
    case intendedRootHasIncoming(stageID: UUID)
    case safetyGatesPrimary(connectionID: UUID)
}

struct SkillTopologyValidationResult: Equatable {
    let issues: [SkillTopologyValidationIssue]

    var isValid: Bool { issues.isEmpty }
}

enum SkillTopologyValidator {
    static func validate(
        skill: Skill,
        allStages: [SkillStage],
        connections: [SkillStageConnection],
        intendedRootStageIDs: Set<UUID>? = nil
    ) -> SkillTopologyValidationResult {
        let skillStages = skill.stages.sorted { $0.id.uuidString < $1.id.uuidString }
        let skillStageIDs = Set(skillStages.map(\.id))
        let allStagesByID = allStages.reduce(into: [UUID: SkillStage]()) { result, stage in
            result[stage.id] = result[stage.id] ?? stage
        }
        var issues: [SkillTopologyValidationIssue] = []

        for stage in skillStages {
            if stage.skill?.id != skill.id {
                issues.append(.stageOutsideSkill(stageID: stage.id))
            }
            if stage.nodeKind == nil {
                issues.append(.invalidNodeKind(stageID: stage.id))
            }
            if stage.prerequisiteMode == nil {
                issues.append(.invalidPrerequisiteMode(stageID: stage.id))
            }
            if stage.requirements.isEmpty {
                issues.append(.missingRequirements(stageID: stage.id))
            }
            if stage.isSkillCompletion && stage.nodeKind != .primary {
                issues.append(.nonPrimaryCompletion(stageID: stage.id))
            }
        }
        if !skillStages.contains(where: { $0.isSkillCompletion && $0.nodeKind == .primary }) {
            issues.append(.missingPrimaryCompletion)
        }

        var validLocalConnections: [SkillStageConnection] = []
        for connection in connections.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let source = allStagesByID[connection.sourceStageID]
            let destination = allStagesByID[connection.destinationStageID]
            if source == nil {
                issues.append(.danglingSource(
                    connectionID: connection.id,
                    stageID: connection.sourceStageID
                ))
            }
            if destination == nil {
                issues.append(.danglingDestination(
                    connectionID: connection.id,
                    stageID: connection.destinationStageID
                ))
            }
            if let liveSource = connection.sourceStage,
               liveSource.id != connection.sourceStageID {
                issues.append(.inconsistentSourceRelationship(connectionID: connection.id))
            }
            if let liveDestination = connection.destinationStage,
               liveDestination.id != connection.destinationStageID {
                issues.append(.inconsistentDestinationRelationship(connectionID: connection.id))
            }
            guard let source, let destination else { continue }
            guard source.skill?.id == skill.id,
                  destination.skill?.id == skill.id,
                  skillStageIDs.contains(source.id),
                  skillStageIDs.contains(destination.id) else {
                issues.append(.crossSkillConnection(connectionID: connection.id))
                continue
            }
            guard source.id != destination.id else {
                issues.append(.selfConnection(connectionID: connection.id, stageID: source.id))
                continue
            }
            if source.nodeKind == .safety && destination.nodeKind == .primary {
                issues.append(.safetyGatesPrimary(connectionID: connection.id))
            }
            validLocalConnections.append(connection)
        }

        if containsCycle(stageIDs: skillStageIDs, connections: validLocalConnections) {
            issues.append(.cycleDetected)
        }

        if let intendedRootStageIDs {
            for rootID in intendedRootStageIDs.sorted(by: uuidLessThan) where !skillStageIDs.contains(rootID) {
                issues.append(.unknownIntendedRoot(stageID: rootID))
            }
            let destinationIDs = Set(validLocalConnections.map(\.destinationStageID))
            let actualRootIDs = skillStageIDs.subtracting(destinationIDs)
            for rootID in actualRootIDs.subtracting(intendedRootStageIDs).sorted(by: uuidLessThan) {
                issues.append(.unexpectedRoot(stageID: rootID))
            }
            for rootID in intendedRootStageIDs.intersection(destinationIDs).sorted(by: uuidLessThan) {
                issues.append(.intendedRootHasIncoming(stageID: rootID))
            }
        }

        return SkillTopologyValidationResult(issues: issues)
    }

    private static func containsCycle(
        stageIDs: Set<UUID>,
        connections: [SkillStageConnection]
    ) -> Bool {
        let adjacency = Dictionary(grouping: connections, by: \.sourceStageID)
            .mapValues { $0.map(\.destinationStageID).sorted(by: uuidLessThan) }
        var visiting = Set<UUID>()
        var visited = Set<UUID>()

        func visit(_ stageID: UUID) -> Bool {
            if visiting.contains(stageID) { return true }
            if visited.contains(stageID) { return false }
            visiting.insert(stageID)
            for destinationID in adjacency[stageID] ?? [] where visit(destinationID) {
                return true
            }
            visiting.remove(stageID)
            visited.insert(stageID)
            return false
        }

        return stageIDs.sorted(by: uuidLessThan).contains(where: visit)
    }

    nonisolated private static func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

enum ExerciseAvailabilityResolver {
    static func resolve(
        variationID: UUID,
        mappings: [VariationEquipmentMapping],
        availableEquipmentIDs: Set<UUID>
    ) -> ExerciseAvailability {
        let canonicalEquipmentIDs = Set(EquipmentCatalog.items.map(\.id))
        let matching = mappings.filter { $0.variationID == variationID }
        guard matching.count == 1, let mapping = matching.first else { return .unknown }
        guard let kind = mapping.kind else { return .unknown }

        switch kind {
        case .baselineOnly:
            return mapping.setups.isEmpty ? .available : .unknown
        case .configured:
            guard !mapping.setups.isEmpty else { return .unknown }
            var sawKnownValidSetup = false
            var sawUnresolvedSetup = false
            for setup in mapping.setups {
                let equipmentIDs = setup.items.map(\.equipmentID)
                guard !equipmentIDs.isEmpty else {
                    sawUnresolvedSetup = true
                    continue
                }
                guard equipmentIDs.allSatisfy(canonicalEquipmentIDs.contains) else {
                    sawUnresolvedSetup = true
                    continue
                }
                sawKnownValidSetup = true
                if Set(equipmentIDs).isSubset(of: availableEquipmentIDs.intersection(canonicalEquipmentIDs)) {
                    return .available
                }
            }
            if sawUnresolvedSetup { return .unknown }
            return sawKnownValidSetup ? .unavailable : .unknown
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
