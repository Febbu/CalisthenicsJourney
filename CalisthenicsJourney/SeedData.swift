import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func installIfNeeded(context: ModelContext, existingExerciseCount: Int) throws {
        try AthleteProfileBootstrap.installIfNeeded(context: context)
        try EvidenceMigration.migrateLegacyExerciseEvidenceIfNeeded(context: context)
        try RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
        try CanonicalV1Content.installIfNeeded(context: context)
        try context.save()
    }
}
