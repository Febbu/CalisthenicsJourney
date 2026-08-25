import SwiftData
import SwiftUI

struct EquipmentSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \EquipmentDefinition.displayName) private var equipment: [EquipmentDefinition]

    var body: some View {
        List(equipment) { definition in
            Toggle(definition.displayName, isOn: availabilityBinding(for: definition))
        }
        .navigationTitle("Equipment")
    }

    private func availabilityBinding(for definition: EquipmentDefinition) -> Binding<Bool> {
        Binding(
            get: {
                profiles.first?.equipmentAvailability.first(where: {
                    $0.equipmentID == definition.id
                })?.isAvailable ?? false
            },
            set: { isAvailable in
                guard let profile = profiles.first else { return }
                EquipmentAvailabilityManager.setAvailable(
                    isAvailable,
                    equipmentID: definition.id,
                    profile: profile
                )
                try? modelContext.save()
            }
        )
    }
}

struct SkillGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \Skill.name) private var skills: [Skill]

    private var profile: AthleteProfile? { profiles.first }

    private var selectedGoals: [SkillGoal] {
        guard let profile else { return [] }
        return SkillGoalManager.orderedSelectedGoals(profile.skillGoals)
    }

    private var unselectedSkills: [Skill] {
        let selectedIDs = Set(selectedGoals.map(\.skillID))
        return skills.filter { !selectedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section("Selected Priority") {
                ForEach(selectedGoals) { goal in
                    HStack {
                        Text(goal.skill?.name ?? "Unavailable Skill")
                        Spacer()
                        Text("#\(goal.priority + 1)")
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Deselect", role: .destructive) {
                            deselect(goal)
                        }
                    }
                }
                .onMove(perform: moveGoals)

                if selectedGoals.isEmpty {
                    Text("No selected skill goals")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Available Skills") {
                ForEach(unselectedSkills) { skill in
                    Button {
                        select(skill)
                    } label: {
                        Label(skill.name, systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("Skill Goals")
        .toolbar { EditButton() }
    }

    private func select(_ skill: Skill) {
        guard let profile else { return }
        SkillGoalManager.select(skill: skill, profile: profile, context: modelContext)
        try? modelContext.save()
    }

    private func deselect(_ goal: SkillGoal) {
        guard let profile else { return }
        SkillGoalManager.deselect(skillID: goal.skillID, profile: profile, context: modelContext)
        try? modelContext.save()
    }

    private func moveGoals(from source: IndexSet, to destination: Int) {
        guard let profile else { return }
        var reordered = selectedGoals
        reordered.move(fromOffsets: source, toOffset: destination)
        SkillGoalManager.reorder(
            selectedGoalIDs: reordered.map(\.id),
            profile: profile,
            context: modelContext
        )
        try? modelContext.save()
    }
}
