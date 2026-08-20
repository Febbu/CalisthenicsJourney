import SwiftUI
import SwiftData

struct SkillsView: View {
    @Query(sort: \Skill.name) private var skills: [Skill]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(skills) { skill in
                    NavigationLink {
                        SkillDetailView(skill: skill)
                    } label: {
                        SkillCard(skill: skill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Your Skills")
    }
}

private struct SkillCard: View {
    let skill: Skill

    private var stages: [SkillStage] {
        skill.stages.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completed: Int {
        stages.filter(\.isCompleted).count
    }

    private var currentName: String {
        stages.first(where: \.isCurrent)?.name ?? (skill.unlockLevel == nil ? "Not started" : "Locked")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(skill.emoji)
                    .font(.title)
                Text(skill.name.uppercased())
                    .font(.headline)
                Spacer()

                if let level = skill.unlockLevel {
                    Label("L\(level)", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.ProgressView(value: Double(completed), total: Double(max(stages.count, 1)))
            
            Text(stages.isEmpty ? "Editable skill — stages coming next." : "\(completed)/\(stages.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Current: \(currentName)")
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SkillDetailView: View {
    let skill: Skill

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(skill.stages.sorted(by: { $0.orderIndex < $1.orderIndex })) { stage in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: icon(for: stage))
                            .font(.title3)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stage.name)
                                .font(.headline)

                            if stage.isCurrent {
                                Text("CURRENT")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 14)

                    if stage.id != skill.stages.sorted(by: { $0.orderIndex < $1.orderIndex }).last?.id {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("🏆 \(skill.name.uppercased()) MASTERED")
                    .font(.headline)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("\(skill.emoji) \(skill.name)")
    }

    private func icon(for stage: SkillStage) -> String {
        if stage.isCompleted { return "checkmark.circle.fill" }
        if stage.isCurrent { return "play.circle.fill" }
        return "circle"
    }
}
