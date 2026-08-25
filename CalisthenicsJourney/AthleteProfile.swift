import Foundation
import SwiftData

enum EquipmentKind: String, Codable, CaseIterable, Hashable {
    case pullUpBar
    case dipBars
    case parallettes
    case gymnasticRings
    case suspensionTrainer
    case resistanceBands
    case benchOrBox
    case lowBar
    case dumbbells
    case weightVest
    case dipBeltAndWeights
    case smithMachine
    case functionalTrainer
    case latPulldownMachine
    case seatedCableRowMachine
    case chestOrShoulderPressMachine
    case legPress
}

struct EquipmentCatalogItem: Equatable {
    let id: UUID
    let kind: EquipmentKind
    let displayName: String
}

enum EquipmentCatalog {
    static let items: [EquipmentCatalogItem] = [
        item("00000000-0000-0000-0000-000000000301", .pullUpBar, "Pull-Up Bar"),
        item("00000000-0000-0000-0000-000000000302", .dipBars, "Dip Bars / Parallel Bars"),
        item("00000000-0000-0000-0000-000000000303", .parallettes, "Parallettes"),
        item("00000000-0000-0000-0000-000000000304", .gymnasticRings, "Gymnastic Rings"),
        item("00000000-0000-0000-0000-000000000305", .suspensionTrainer, "Suspension Trainer (e.g. TRX)"),
        item("00000000-0000-0000-0000-000000000306", .resistanceBands, "Resistance Bands"),
        item("00000000-0000-0000-0000-000000000307", .benchOrBox, "Bench / Box"),
        item("00000000-0000-0000-0000-000000000308", .lowBar, "Low Bar"),
        item("00000000-0000-0000-0000-000000000309", .dumbbells, "Dumbbells"),
        item("00000000-0000-0000-0000-00000000030A", .weightVest, "Weight Vest"),
        item("00000000-0000-0000-0000-00000000030B", .dipBeltAndWeights, "Dip Belt + Weights"),
        item("00000000-0000-0000-0000-00000000030C", .smithMachine, "Smith Machine"),
        item("00000000-0000-0000-0000-00000000030D", .functionalTrainer, "Functional Trainer / Cable Machine"),
        item("00000000-0000-0000-0000-00000000030E", .latPulldownMachine, "Lat Pulldown Machine"),
        item("00000000-0000-0000-0000-00000000030F", .seatedCableRowMachine, "Seated Cable Row Machine"),
        item("00000000-0000-0000-0000-000000000310", .chestOrShoulderPressMachine, "Chest / Shoulder Press Machine"),
        item("00000000-0000-0000-0000-000000000311", .legPress, "Leg Press")
    ]

    private static func item(_ id: String, _ kind: EquipmentKind, _ name: String) -> EquipmentCatalogItem {
        EquipmentCatalogItem(id: UUID(uuidString: id)!, kind: kind, displayName: name)
    }

    static func kind(for id: UUID) -> EquipmentKind? {
        items.first(where: { $0.id == id })?.kind
    }
}

@Model
final class EquipmentDefinition {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var kindRaw: String
    var displayName: String
    var createdAt: Date
    var updatedAt: Date

    var kind: EquipmentKind? { EquipmentKind(rawValue: kindRaw) }

    init(id: UUID, kind: EquipmentKind, displayName: String) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.displayName = displayName
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class AthleteProfile {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \EquipmentAvailability.profile)
    var equipmentAvailability: [EquipmentAvailability] = []

    @Relationship(deleteRule: .cascade, inverse: \SkillGoal.profile)
    var skillGoals: [SkillGoal] = []

    init(id: UUID = UUID()) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class EquipmentAvailability {
    @Attribute(.unique) var id: UUID
    var equipmentID: UUID
    var isAvailable: Bool
    var updatedAt: Date
    var equipment: EquipmentDefinition?
    var profile: AthleteProfile?

    init(
        equipment: EquipmentDefinition,
        isAvailable: Bool = false,
        profile: AthleteProfile
    ) {
        self.id = UUID()
        self.equipmentID = equipment.id
        self.isAvailable = isAvailable
        self.updatedAt = .now
        self.equipment = equipment
        self.profile = profile
    }
}

@Model
final class SkillGoal {
    @Attribute(.unique) var id: UUID
    var skillID: UUID
    var isSelected: Bool
    var priority: Int
    var createdAt: Date
    var updatedAt: Date
    var skill: Skill?
    var profile: AthleteProfile?

    init(skill: Skill, priority: Int, isSelected: Bool = true, profile: AthleteProfile) {
        self.id = UUID()
        self.skillID = skill.id
        self.isSelected = isSelected
        self.priority = priority
        self.createdAt = .now
        self.updatedAt = .now
        self.skill = skill
        self.profile = profile
    }
}

struct EquipmentSetupOption: Equatable {
    let requiredKinds: Set<EquipmentKind>

    init(_ requiredKinds: Set<EquipmentKind>) {
        self.requiredKinds = requiredKinds
    }
}

struct EquipmentRequirement: Equatable {
    let options: [EquipmentSetupOption]

    static let baselineOnly = EquipmentRequirement(options: [])

    func isSatisfied(by availableKinds: Set<EquipmentKind>) -> Bool {
        options.isEmpty || options.contains { $0.requiredKinds.isSubset(of: availableKinds) }
    }
}

enum SkillTrainability: Equatable {
    case trainable
    case temporarilyUnavailable
    case unknown

    var isEligibleForFocus: Bool {
        self != .temporarilyUnavailable
    }
}

struct SkillFocusState: Equatable {
    let focusGoalIDs: [UUID]
    let queuedGoalIDs: [UUID]
}

enum SkillFocusResolver {
    static func resolve(
        goals: [SkillGoal],
        masteredSkillIDs: Set<UUID>,
        trainabilityBySkillID: [UUID: SkillTrainability]
    ) -> SkillFocusState {
        let eligible = SkillGoalManager.orderedSelectedGoals(goals).filter { goal in
            !masteredSkillIDs.contains(goal.skillID)
                && (trainabilityBySkillID[goal.skillID] ?? .unknown).isEligibleForFocus
        }
        return SkillFocusState(
            focusGoalIDs: eligible.prefix(3).map(\.id),
            queuedGoalIDs: eligible.dropFirst(3).map(\.id)
        )
    }
}

@MainActor
enum AthleteProfileBootstrap {
    static let localProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static func installIfNeeded(context: ModelContext) throws {
        let existingDefinitions = try context.fetch(FetchDescriptor<EquipmentDefinition>())
        var definitionsByKind = Dictionary(uniqueKeysWithValues: existingDefinitions.map { ($0.kindRaw, $0) })

        for item in EquipmentCatalog.items {
            if let definition = definitionsByKind[item.kind.rawValue] {
                if definition.displayName != item.displayName {
                    definition.displayName = item.displayName
                    definition.updatedAt = .now
                }
            } else {
                let definition = EquipmentDefinition(id: item.id, kind: item.kind, displayName: item.displayName)
                context.insert(definition)
                definitionsByKind[item.kind.rawValue] = definition
            }
        }

        let existingProfiles = try context.fetch(FetchDescriptor<AthleteProfile>())
        let profile: AthleteProfile
        if let existing = existingProfiles.first(where: { $0.id == localProfileID }) ?? existingProfiles.first {
            profile = existing
        } else {
            profile = AthleteProfile(id: localProfileID)
            context.insert(profile)
        }

        _ = SkillGoalManager.repairDuplicates(profile: profile, context: context)
        repairEquipmentAvailability(
            profile: profile,
            definitionsByKind: definitionsByKind,
            context: context
        )
    }

    private static func repairEquipmentAvailability(
        profile: AthleteProfile,
        definitionsByKind: [String: EquipmentDefinition],
        context: ModelContext
    ) {
        let grouped = Dictionary(grouping: profile.equipmentAvailability, by: \.equipmentID)
        var availabilityByEquipmentID: [UUID: EquipmentAvailability] = [:]

        for (equipmentID, rows) in grouped {
            let ordered = rows.sorted { $0.id.uuidString < $1.id.uuidString }
            guard let survivor = ordered.first else { continue }
            survivor.isAvailable = ordered.contains(where: \.isAvailable)
            survivor.updatedAt = ordered.map(\.updatedAt).max() ?? survivor.updatedAt

            if let kind = EquipmentCatalog.kind(for: equipmentID),
               let definition = definitionsByKind[kind.rawValue] {
                survivor.equipment = definition
            } else if survivor.equipment?.id != equipmentID {
                survivor.equipment = nil
            }

            ordered.dropFirst().forEach(context.delete)
            availabilityByEquipmentID[equipmentID] = survivor
        }

        for item in EquipmentCatalog.items {
            guard availabilityByEquipmentID[item.id] == nil,
                  let definition = definitionsByKind[item.kind.rawValue] else { continue }
            let availability = EquipmentAvailability(equipment: definition, profile: profile)
            context.insert(availability)
            availabilityByEquipmentID[item.id] = availability
        }
    }

}

@MainActor
enum EquipmentAvailabilityManager {
    static func setAvailable(
        _ isAvailable: Bool,
        equipmentID: UUID,
        profile: AthleteProfile
    ) {
        let matching = profile.equipmentAvailability.filter { $0.equipmentID == equipmentID }
        guard !matching.isEmpty else { return }
        for availability in matching {
            availability.isAvailable = isAvailable
            availability.updatedAt = .now
        }
        profile.updatedAt = .now
    }

    static func availableKinds(for profile: AthleteProfile) -> Set<EquipmentKind> {
        Set(profile.equipmentAvailability.compactMap { availability in
            guard availability.isAvailable else { return nil }
            if let equipment = availability.equipment,
               equipment.id == availability.equipmentID,
               let kind = equipment.kind {
                return kind
            }
            return EquipmentCatalog.kind(for: availability.equipmentID)
        })
    }
}

@MainActor
enum SkillGoalManager {
    static func orderedSelectedGoals(_ goals: [SkillGoal]) -> [SkillGoal] {
        let ordered = goals.filter(\.isSelected).sorted {
            if $0.priority == $1.priority { return $0.id.uuidString < $1.id.uuidString }
            return $0.priority < $1.priority
        }
        var seenSkillIDs = Set<UUID>()
        return ordered.filter { seenSkillIDs.insert($0.skillID).inserted }
    }

    @discardableResult
    static func select(skill: Skill, profile: AthleteProfile, context: ModelContext) -> SkillGoal {
        let repaired = repairDuplicates(profile: profile, context: context)
        if let existing = repaired.first(where: { $0.skillID == skill.id }) {
            if !existing.isSelected {
                existing.isSelected = true
                existing.priority = nextPriority(in: repaired)
                existing.updatedAt = .now
                normalize(profile: profile)
            }
            return existing
        }

        let goal = SkillGoal(skill: skill, priority: nextPriority(in: repaired), profile: profile)
        context.insert(goal)
        profile.updatedAt = .now
        normalize(goals: repaired + [goal])
        return goal
    }

    static func deselect(skillID: UUID, profile: AthleteProfile, context: ModelContext) {
        let repaired = repairDuplicates(profile: profile, context: context)
        guard let goal = repaired.first(where: { $0.skillID == skillID && $0.isSelected }) else {
            return
        }
        goal.isSelected = false
        goal.updatedAt = .now
        profile.updatedAt = .now
        normalize(goals: repaired)
    }

    static func reorder(selectedGoalIDs: [UUID], profile: AthleteProfile, context: ModelContext) {
        let repaired = repairDuplicates(profile: profile, context: context)
        let selected = orderedSelectedGoals(repaired)
        let selectedByID = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var ordered = selectedGoalIDs.compactMap { id -> SkillGoal? in
            guard seen.insert(id).inserted else { return nil }
            return selectedByID[id]
        }
        ordered.append(contentsOf: selected.filter { !seen.contains($0.id) })
        for (index, goal) in ordered.enumerated() {
            goal.priority = index
            goal.updatedAt = .now
        }
        profile.updatedAt = .now
    }

    static func normalize(profile: AthleteProfile) {
        normalize(goals: profile.skillGoals)
    }

    private static func normalize(goals: [SkillGoal]) {
        for (index, goal) in orderedSelectedGoals(goals).enumerated() {
            goal.priority = index
        }
    }

    private static func nextPriority(in goals: [SkillGoal]) -> Int {
        (orderedSelectedGoals(goals).map(\.priority).max() ?? -1) + 1
    }

    static func repairDuplicates(profile: AthleteProfile, context: ModelContext) -> [SkillGoal] {
        let grouped = Dictionary(grouping: profile.skillGoals, by: \.skillID)
        var survivors: [SkillGoal] = []
        for (_, rows) in grouped {
            let ordered = rows.sorted { $0.id.uuidString < $1.id.uuidString }
            guard let survivor = ordered.first else { continue }
            let selected = ordered.filter(\.isSelected)
            survivor.isSelected = !selected.isEmpty
            survivor.priority = (selected.isEmpty ? ordered : selected).map(\.priority).min() ?? survivor.priority
            survivor.createdAt = ordered.map(\.createdAt).min() ?? survivor.createdAt
            survivor.updatedAt = ordered.map(\.updatedAt).max() ?? survivor.updatedAt
            survivor.skill = ordered.compactMap(\.skill).first(where: { $0.id == survivor.skillID })
            ordered.dropFirst().forEach(context.delete)
            survivors.append(survivor)
        }
        normalize(goals: survivors)
        return survivors
    }
}
