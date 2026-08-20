import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]

    let session: WorkoutSession
    @State private var exerciseIndex = 0
    @State private var showFinished = false

    private var logs: [ExerciseLog] {
        session.exerciseLogs.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        Group {
            if logs.indices.contains(exerciseIndex) {
                ExerciseEntryView(
                    log: logs[exerciseIndex],
                    previousLog: previousLog(for: logs[exerciseIndex]),
                    isLast: exerciseIndex == logs.count - 1,
                    onNext: next
                )
            } else {
                ContentUnavailableView("No exercises", systemImage: "dumbbell")
            }
        }
        .navigationTitle("\(exerciseIndex + 1) of \(max(logs.count, 1))")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Workout Complete 🎉", isPresented: $showFinished) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your results are saved and will appear as your previous results next time.")
        }
    }

    private func previousLog(for current: ExerciseLog) -> ExerciseLog? {
        allSessions
            .filter { $0.id != session.id && $0.startedAt < session.startedAt }
            .compactMap { other in
                other.exerciseLogs.first(where: { $0.exerciseID == current.exerciseID })
            }
            .first
    }

    private func next() {
        try? modelContext.save()

        if exerciseIndex < logs.count - 1 {
            exerciseIndex += 1
        } else {
            session.completedAt = .now
            try? modelContext.save()
            showFinished = true
        }
    }
}

private struct ExerciseEntryView: View {
    let log: ExerciseLog
    let previousLog: ExerciseLog?
    let isLast: Bool
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(log.exerciseName)
                        .font(.largeTitle.bold())

                    if previousLog == nil {
                        Text("First time — enter what you actually achieve.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Previous vs. today")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(log.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                    SetEntryCard(
                        set: set,
                        previous: previousLog?.sets.first(where: { $0.setNumber == set.setNumber }),
                        metric: log.metric
                    )
                }

                Button(action: onNext) {
                    Text(isLast ? "Finish Workout" : "Next Exercise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

private struct SetEntryCard: View {
    @Bindable var set: SetLog
    let previous: SetLog?
    let metric: ExerciseMetric
    
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SET \(set.setNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let previous {
                HStack {
                    Text("Previous")
                    Spacer()
                    Text(previousText(previous))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
            }

            switch metric {

            case .reps:
                VStack(alignment: .leading) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("reps", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .focused($inputIsFocused)
                        .textFieldStyle(.roundedBorder)
                }

            case .seconds:
                VStack(alignment: .leading) {
                    Text("Seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("sec", value: $set.seconds, format: .number)
                        .keyboardType(.numberPad)
                        .focused($inputIsFocused)
                        .textFieldStyle(.roundedBorder)
                }

            case .weightAndReps:
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("lb", value: $set.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($inputIsFocused)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("reps", value: $set.reps, format: .number)
                            .keyboardType(.numberPad)
                            .focused($inputIsFocused)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    inputIsFocused = false
                }
            }
        }
    }

    private func previousText(_ previous: SetLog) -> String {
        if let weight = previous.weight, let reps = previous.reps {
            return "\(weight.formatted()) lb × \(reps)"
        }
        if let reps = previous.reps {
            return "\(reps) reps"
        }
        if let seconds = previous.seconds {
            return "\(seconds)s"
        }
        return "—"
    }
}
