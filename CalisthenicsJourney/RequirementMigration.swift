import SwiftData

@MainActor
enum RequirementMigration {
    static func migrateLegacyRequirementsIfNeeded(context: ModelContext) throws {
        let legacyRequirements = try context.fetch(FetchDescriptor<LevelRequirement>())
        let existingRequirements = try context.fetch(FetchDescriptor<Requirement>())
        var migratedIDs = Set(existingRequirements.map(\.id))

        for legacy in legacyRequirements where !migratedIDs.contains(legacy.id) {
            guard let journeyLevel = legacy.level else { continue }

            let requirement = Requirement(
                id: legacy.id,
                title: legacy.title,
                exerciseID: legacy.exerciseID,
                metric: legacy.metric,
                targetReps: legacy.targetReps,
                targetWeight: legacy.targetWeight,
                targetSeconds: legacy.targetSeconds,
                confirmationsNeeded: legacy.confirmationsNeeded,
                journeyLevel: journeyLevel
            )
            context.insert(requirement)
            migratedIDs.insert(legacy.id)
        }
    }
}
