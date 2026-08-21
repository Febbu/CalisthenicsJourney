import SwiftUI
import SwiftData

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
            SeedData.installIfNeeded(
                context: modelContext,
                existingExerciseCount: exercises.count
            )
        }
    }
}
