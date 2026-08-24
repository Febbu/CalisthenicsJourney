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
        ContentUnavailableView {
            Label("Dashboard", systemImage: "rectangle.grid.2x2")
        } description: {
            Text("Demonstrated abilities and current training state will appear here as skill progression evolves.")
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
