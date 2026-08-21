import Foundation

struct RequirementEvaluation {
    let qualifyingSessionCount: Int
    let confirmationsNeeded: Int

    var confirmedCount: Int {
        min(qualifyingSessionCount, confirmationsNeeded)
    }

    var isMastered: Bool {
        qualifyingSessionCount >= confirmationsNeeded
    }
}

enum RequirementEvaluator {
    static func evaluate(
        _ requirement: LevelRequirement,
        against sessions: [WorkoutSession]
    ) -> RequirementEvaluation {
        let qualifyingSessionIDs = Set(
            sessions.compactMap { session in
                sessionQualifies(session, for: requirement) ? session.id : nil
            }
        )

        return RequirementEvaluation(
            qualifyingSessionCount: qualifyingSessionIDs.count,
            confirmationsNeeded: requirement.confirmationsNeeded
        )
    }

    private static func sessionQualifies(
        _ session: WorkoutSession,
        for requirement: LevelRequirement
    ) -> Bool {
        session.exerciseLogs.contains { log in
            guard log.exerciseID == requirement.exerciseID else { return false }
            return log.sets.contains { setQualifies($0, for: requirement) }
        }
    }

    private static func setQualifies(
        _ set: SetLog,
        for requirement: LevelRequirement
    ) -> Bool {
        switch requirement.metric {
        case .reps:
            guard let target = requirement.targetReps,
                  let reps = set.reps else { return false }
            return reps >= target

        case .seconds:
            guard let target = requirement.targetSeconds,
                  let seconds = set.seconds else { return false }
            return seconds >= target

        case .weightAndReps:
            guard let targetWeight = requirement.targetWeight,
                  let targetReps = requirement.targetReps,
                  let weight = set.weight,
                  let reps = set.reps else { return false }
            return weight >= targetWeight && reps >= targetReps
        }
    }
}
