import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var activeSession: WorkoutSession?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 54))

            Text("Ready to train?")
                .font(.largeTitle.bold())

            if let template = templates.first {
                Text(template.name)
                    .foregroundStyle(.secondary)

                Button {
                    activeSession = createSession(from: template)
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                Text("Your workout is being set up.")
                    .foregroundStyle(.secondary)
            }

            if let last = sessions.first {
                Text("Last workout: \(last.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                ProgressView()
            } label: {
                Label("Workout History", systemImage: "clock.arrow.circlepath")
            }

            Spacer()
        }
        .navigationTitle("Workout")
        .navigationDestination(item: $activeSession) { session in
            ActiveWorkoutView(session: session)
        }
    }

    private func createSession(from template: WorkoutTemplate) -> WorkoutSession {
        let session = WorkoutSession(workoutName: template.name)
        modelContext.insert(session)

        for item in template.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exercise = item.exercise else { continue }
            let variation = EvidenceMigration.defaultVariation(
                for: exercise,
                context: modelContext
            )
            let log = ExerciseLog(
                exercise: exercise,
                variation: variation,
                orderIndex: item.orderIndex,
                session: session
            )
            modelContext.insert(log)
            session.exerciseLogs.append(log)

            for number in 1...item.targetSets {
                let set = SetLog(
                    setNumber: number,
                    targetMinReps: item.minReps,
                    targetMaxReps: item.maxReps,
                    targetSeconds: item.targetSeconds,
                    variation: variation,
                    exerciseLog: log
                )
                modelContext.insert(set)
                log.sets.append(set)
            }
        }

        try? modelContext.save()
        return session
    }
}
