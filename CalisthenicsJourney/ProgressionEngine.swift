import Foundation

enum SkillStageProgressionState: Equatable {
    case completed
    case current
    case futureLocked
}

struct SkillStageProgress: Equatable {
    let stageID: UUID
    let state: SkillStageProgressionState
}

enum ProgressionEngine {
    static func isMastered(
        _ stage: SkillStage,
        against sessions: [WorkoutSession]
    ) -> Bool {
        RequirementEvaluator.areAllMastered(stage.requirements, against: sessions)
    }

    static func isMastered(
        _ level: JourneyLevel,
        against sessions: [WorkoutSession]
    ) -> Bool {
        RequirementEvaluator.areAllMastered(level.genericRequirements, against: sessions)
    }

    static func orderedStageStates(
        for skill: Skill,
        against sessions: [WorkoutSession]
    ) -> [SkillStageProgress] {
        let orderedStages = skill.stages.sorted {
            if $0.orderIndex == $1.orderIndex {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.orderIndex < $1.orderIndex
        }
        var foundCurrentStage = false

        return orderedStages.map { stage in
            let state: SkillStageProgressionState

            if foundCurrentStage {
                state = .futureLocked
            } else if isMastered(stage, against: sessions) {
                state = .completed
            } else {
                state = .current
                foundCurrentStage = true
            }

            return SkillStageProgress(stageID: stage.id, state: state)
        }
    }
}
