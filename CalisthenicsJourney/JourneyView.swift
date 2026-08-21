import SwiftUI
import SwiftData

struct JourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \JourneyLevel.number) private var levels: [JourneyLevel]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let current = levels.first(where: { $0.isUnlocked }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LEVEL \(current.number)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(current.name.uppercased())
                            .font(.largeTitle.bold())
                        Text("Master every requirement to advance.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(current.genericRequirements) { requirement in
                            RequirementCard(
                                requirement: requirement,
                                evaluation: RequirementEvaluator.evaluate(
                                    requirement,
                                    against: sessions
                                )
                            )
                        }
                    }
                } else {
                    ContentUnavailableView("Journey not set up", systemImage: "gamecontroller")
                }
            }
            .padding()
        }
        .navigationTitle("Journey")
        .toolbar {
            Button {
                // Editing screen comes next.
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .task {
            SeedData.installIfNeeded(context: modelContext, existingExerciseCount: exercises.count)
        }
    }

}

private struct RequirementCard: View {
    let requirement: Requirement
    let evaluation: RequirementEvaluation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: evaluation.isMastered
                  ? "checkmark.circle.fill"
                  : "circle")
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(requirement.title)
                    .font(.headline)

                Text("\(evaluation.confirmedCount) / \(evaluation.confirmationsNeeded) confirmed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
