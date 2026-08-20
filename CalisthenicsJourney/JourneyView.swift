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
                        Text("Master every requirement twice to advance.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(current.requirements) { requirement in
                            RequirementCard(
                                requirement: requirement,
                                confirmations: confirmationCount(for: requirement)
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

    private func confirmationCount(for requirement: LevelRequirement) -> Int {
        let qualifyingSessions = sessions.filter { session in
            session.exerciseLogs.contains { log in
                guard log.exerciseID == requirement.exerciseID else { return false }

                switch requirement.metric {
                case .reps:
                    guard let target = requirement.targetReps else { return false }
                    return log.sets.contains { ($0.reps ?? 0) >= target }

                case .seconds:
                    guard let target = requirement.targetSeconds else { return false }
                    return log.sets.contains { ($0.seconds ?? 0) >= target }

                case .weightAndReps:
                    guard let targetWeight = requirement.targetWeight,
                          let targetReps = requirement.targetReps else { return false }
                    return log.sets.contains {
                        ($0.weight ?? 0) >= targetWeight && ($0.reps ?? 0) >= targetReps
                    }
                }
            }
        }

        return min(qualifyingSessions.count, requirement.confirmationsNeeded)
    }
}

private struct RequirementCard: View {
    let requirement: LevelRequirement
    let confirmations: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: confirmations >= requirement.confirmationsNeeded
                  ? "checkmark.circle.fill"
                  : "circle")
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(requirement.title)
                    .font(.headline)

                Text("\(confirmations) / \(requirement.confirmationsNeeded) confirmed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
