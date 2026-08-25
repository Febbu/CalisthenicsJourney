import SwiftUI
import SwiftData
import OSLog

private let bootstrapLogger = Logger(
    subsystem: "CalisthenicsJourney",
    category: "PersistenceBootstrap"
)

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        List {
            Section {
                Text("Demonstrated abilities and current training state will appear here as skill progression evolves.")
                    .foregroundStyle(.secondary)
            }

            Section("Training Profile") {
                NavigationLink("Equipment", destination: EquipmentSettingsView())
                NavigationLink("Skill Goals", destination: SkillGoalsView())
            }
        }
        .navigationTitle("Dashboard")
        .task {
            do {
                try SeedData.installIfNeeded(
                    context: modelContext,
                    existingExerciseCount: exercises.count
                )
            } catch {
                bootstrapLogger.error(
                    "Evidence migration failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
