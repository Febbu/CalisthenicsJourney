import Foundation

struct RequirementEvaluation: Equatable {
    let requirementID: UUID
    let directEvidenceIDs: [UUID]
    let impliedEvidenceIDs: [UUID]
    let impliedByRequirementIDs: [UUID]

    var qualifyingEvidenceIDs: [UUID] {
        Array(Set(directEvidenceIDs + impliedEvidenceIDs)).sorted { $0.uuidString < $1.uuidString }
    }

    var isSatisfied: Bool { !qualifyingEvidenceIDs.isEmpty }
}

enum RequirementEvaluator {
    static func evaluate(
        _ requirement: Requirement,
        against sessions: [WorkoutSession],
        implications: [RequirementImplication] = []
    ) -> RequirementEvaluation {
        evaluate(
            requirement,
            against: sessions,
            implications: implications,
            visitedRequirementIDs: []
        )
    }

    static func areAllMastered(
        _ requirements: [Requirement],
        against sessions: [WorkoutSession],
        implications: [RequirementImplication] = []
    ) -> Bool {
        !requirements.isEmpty && requirements.allSatisfy {
            evaluate($0, against: sessions, implications: implications).isSatisfied
        }
    }

    private static func evaluate(
        _ requirement: Requirement,
        against sessions: [WorkoutSession],
        implications: [RequirementImplication],
        visitedRequirementIDs: Set<UUID>
    ) -> RequirementEvaluation {
        guard !visitedRequirementIDs.contains(requirement.id) else {
            return RequirementEvaluation(
                requirementID: requirement.id,
                directEvidenceIDs: [],
                impliedEvidenceIDs: [],
                impliedByRequirementIDs: []
            )
        }

        let directEvidenceIDs = qualifyingSets(for: requirement, in: sessions).map(\.id)
        var impliedEvidenceIDs: [UUID] = []
        var impliedByRequirementIDs: [UUID] = []
        let nextVisited = visitedRequirementIDs.union([requirement.id])

        for implication in implications where implication.impliedRequirementID == requirement.id {
            guard let source = implication.sourceRequirement,
                  source.id == implication.sourceRequirementID else { continue }
            let sourceEvaluation = evaluate(
                source,
                against: sessions,
                implications: implications,
                visitedRequirementIDs: nextVisited
            )
            guard sourceEvaluation.isSatisfied else { continue }
            impliedEvidenceIDs.append(contentsOf: sourceEvaluation.qualifyingEvidenceIDs)
            impliedByRequirementIDs.append(source.id)
        }

        return RequirementEvaluation(
            requirementID: requirement.id,
            directEvidenceIDs: directEvidenceIDs.sorted { $0.uuidString < $1.uuidString },
            impliedEvidenceIDs: Array(Set(impliedEvidenceIDs)).sorted { $0.uuidString < $1.uuidString },
            impliedByRequirementIDs: Array(Set(impliedByRequirementIDs)).sorted {
                $0.uuidString < $1.uuidString
            }
        )
    }

    private static func qualifyingSets(
        for requirement: Requirement,
        in sessions: [WorkoutSession]
    ) -> [SetLog] {
        guard let requiredVariationID = requirement.variationID else { return [] }

        return sessions.flatMap(\.exerciseLogs).flatMap(\.sets).filter { set in
            guard set.hasActualPerformanceEvidence,
                  set.evidenceVariationID == requiredVariationID,
                  set.side == requirement.side else { return false }
            return setQualifies(set, for: requirement)
        }
    }

    private static func setQualifies(
        _ set: SetLog,
        for requirement: Requirement
    ) -> Bool {
        switch requirement.evidenceKind {
        case .reps:
            guard set.effortKind == .numeric,
                  set.evidenceMetric == .reps,
                  let target = requirement.targetReps,
                  let reps = set.reps else { return false }
            return reps >= target

        case .seconds:
            guard set.effortKind == .numeric,
                  set.evidenceMetric == .seconds,
                  let target = requirement.targetSeconds,
                  let seconds = set.seconds else { return false }
            return seconds >= target

        case .weightAndReps:
            guard set.effortKind == .numeric,
                  set.evidenceMetric == .weightAndReps,
                  let targetWeight = requirement.targetWeight,
                  let targetReps = requirement.targetReps,
                  let weight = set.weight,
                  let reps = set.reps else { return false }
            return weight >= targetWeight && reps >= targetReps

        case .successfulAttempt:
            return set.effortKind == .attempt && set.attemptOutcome == .successful
        }
    }
}
