import SwiftUI
import SwiftData

struct ProgressView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        List {
            Section("Workout History") {
                if sessions.isEmpty {
                    Text("Your completed workouts will appear here.")
                        .foregroundStyle(.secondary)
                }

                ForEach(sessions) { session in
                    NavigationLink {
                        WorkoutHistoryDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.workoutName)
                                .font(.headline)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Progress")
    }
}

private struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            ForEach(session.exerciseLogs.sorted(by: { $0.orderIndex < $1.orderIndex })) { log in
                Section(log.exerciseName) {
                    ForEach(log.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                            Spacer()
                            Text(summary(set))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .omitted))
    }

    private func summary(_ set: SetLog) -> String {
        if let w = set.weight, let r = set.reps {
            return "\(w.formatted()) lb × \(r)"
        }
        if let r = set.reps {
            return "\(r) reps"
        }
        if let s = set.seconds {
            return "\(s)s"
        }
        return "—"
    }
}
