import Foundation
import SwiftData

enum PrescriptionMode: String, Codable, CaseIterable {
    case reps
    case duration
    case attempts
}

enum PrescriptionBasisKind: String, Codable, CaseIterable {
    case estimate
    case exploratory
    case realPerformance
}

struct ThreeWorkingSetValues: Equatable {
    let first: Int
    let second: Int
    let third: Int

    var all: [Int] { [first, second, third] }
}

struct PrescriptionStalenessPolicy: Equatable {
    var threshold: TimeInterval

    nonisolated static let v1 = PrescriptionStalenessPolicy(
        threshold: 6 * 30 * 24 * 60 * 60
    )

    func isStale(referenceDate: Date, asOf date: Date) -> Bool {
        date.timeIntervalSince(referenceDate) >= threshold
    }
}

@Model
final class ExercisePrescriptionState {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var ownershipKey: String
    var athleteID: UUID
    var variationID: UUID
    var modeRaw: String
    var basisKindRaw: String
    var firstWorkingSetValue: Int?
    var secondWorkingSetValue: Int?
    var thirdWorkingSetValue: Int?
    var lastRelevantPerformanceAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var mode: PrescriptionMode? {
        PrescriptionMode(rawValue: modeRaw)
    }

    var basisKind: PrescriptionBasisKind? {
        PrescriptionBasisKind(rawValue: basisKindRaw)
    }

    var workingSetValues: ThreeWorkingSetValues? {
        guard let firstWorkingSetValue,
              let secondWorkingSetValue,
              let thirdWorkingSetValue else { return nil }
        return ThreeWorkingSetValues(
            first: firstWorkingSetValue,
            second: secondWorkingSetValue,
            third: thirdWorkingSetValue
        )
    }

    var hasNumericWorkingSetBasis: Bool {
        workingSetValues != nil
    }

    func isUsable(for requestedMode: PrescriptionMode) -> Bool {
        guard mode == requestedMode, let basisKind else { return false }

        switch basisKind {
        case .realPerformance:
            guard lastRelevantPerformanceAt != nil else { return false }
        case .estimate, .exploratory:
            guard lastRelevantPerformanceAt == nil else { return false }
        }

        switch (requestedMode, basisKind) {
        case (.attempts, .exploratory), (.attempts, .realPerformance):
            return numericWorkingSetValuesAreAbsent
        case (.attempts, .estimate):
            return false
        case (.reps, .exploratory), (.duration, .exploratory):
            return numericWorkingSetValuesAreAbsent
        case (.reps, .estimate), (.reps, .realPerformance),
             (.duration, .estimate), (.duration, .realPerformance):
            return workingSetValues?.all.allSatisfy { $0 > 0 } == true
        }
    }

    private var numericWorkingSetValuesAreAbsent: Bool {
        firstWorkingSetValue == nil
            && secondWorkingSetValue == nil
            && thirdWorkingSetValue == nil
    }

    init(
        athleteID: UUID,
        variationID: UUID,
        mode: PrescriptionMode,
        basisKind: PrescriptionBasisKind,
        workingSetValues: ThreeWorkingSetValues? = nil,
        lastRelevantPerformanceAt: Date? = nil,
        now: Date = .now
    ) {
        self.id = UUID()
        self.ownershipKey = Self.makeOwnershipKey(
            athleteID: athleteID,
            variationID: variationID
        )
        self.athleteID = athleteID
        self.variationID = variationID
        self.modeRaw = mode.rawValue
        self.basisKindRaw = basisKind.rawValue
        self.firstWorkingSetValue = workingSetValues?.first
        self.secondWorkingSetValue = workingSetValues?.second
        self.thirdWorkingSetValue = workingSetValues?.third
        self.lastRelevantPerformanceAt = lastRelevantPerformanceAt
        self.createdAt = now
        self.updatedAt = now
    }

    func requiresRecalibration(
        asOf date: Date,
        policy: PrescriptionStalenessPolicy = .v1
    ) -> Bool {
        policy.isStale(
            referenceDate: lastRelevantPerformanceAt ?? updatedAt,
            asOf: date
        )
    }

    static func makeOwnershipKey(athleteID: UUID, variationID: UUID) -> String {
        "\(athleteID.uuidString)|\(variationID.uuidString)"
    }

    func hasValidOwnership(athleteID: UUID, variationID: UUID) -> Bool {
        self.athleteID == athleteID
            && self.variationID == variationID
            && ownershipKey == Self.makeOwnershipKey(
                athleteID: athleteID,
                variationID: variationID
            )
    }
}

struct PrescriptionHistoryBasis: Equatable {
    let variationID: UUID
    let mode: PrescriptionMode
    let workingSetValues: ThreeWorkingSetValues?
    let performedAt: Date
}

@MainActor
enum PrescriptionHistoryBootstrap {
    static func latestEligibleBasis(
        variationID: UUID,
        mode: PrescriptionMode,
        context: ModelContext,
        asOf date: Date,
        policy: PrescriptionStalenessPolicy = .v1
    ) throws -> PrescriptionHistoryBasis? {
        let sets = try context.fetch(FetchDescriptor<SetLog>())
        let grouped = Dictionary(grouping: sets.compactMap { set -> (UUID, SetLog)? in
            guard let logID = set.exerciseLog?.id else { return nil }
            return (logID, set)
        }, by: { $0.0 })

        let candidates = grouped.values.compactMap { entries -> PrescriptionHistoryBasis? in
            eligibleBasis(
                sets: entries.map(\.1),
                variationID: variationID,
                mode: mode
            )
        }

        return candidates
            .filter { !policy.isStale(referenceDate: $0.performedAt, asOf: date) }
            .max { $0.performedAt < $1.performedAt }
    }

    private static func eligibleBasis(
        sets: [SetLog],
        variationID: UUID,
        mode: PrescriptionMode
    ) -> PrescriptionHistoryBasis? {
        let performed = sets.filter(\.hasActualPerformanceEvidence)
        guard !performed.isEmpty,
              performed.allSatisfy({ $0.evidenceVariationID == variationID }),
              let performedAt = performed.first?.exerciseLog?.session.map({
                  $0.completedAt ?? $0.startedAt
              }) else { return nil }

        switch mode {
        case .reps:
            let ordered = performed.sorted { $0.setNumber < $1.setNumber }
            guard ordered.count == 3,
                  ordered.allSatisfy({ !$0.isAttempt && $0.evidenceMetric == .reps }),
                  let first = ordered[0].reps,
                  let second = ordered[1].reps,
                  let third = ordered[2].reps,
                  [first, second, third].allSatisfy({ $0 > 0 }) else { return nil }
            return PrescriptionHistoryBasis(
                variationID: variationID,
                mode: mode,
                workingSetValues: ThreeWorkingSetValues(
                    first: first,
                    second: second,
                    third: third
                ),
                performedAt: performedAt
            )
        case .duration:
            let ordered = performed.sorted { $0.setNumber < $1.setNumber }
            guard ordered.count == 3,
                  ordered.allSatisfy({ !$0.isAttempt && $0.evidenceMetric == .seconds }),
                  let first = ordered[0].seconds,
                  let second = ordered[1].seconds,
                  let third = ordered[2].seconds,
                  [first, second, third].allSatisfy({ $0 > 0 }) else { return nil }
            return PrescriptionHistoryBasis(
                variationID: variationID,
                mode: mode,
                workingSetValues: ThreeWorkingSetValues(
                    first: first,
                    second: second,
                    third: third
                ),
                performedAt: performedAt
            )
        case .attempts:
            guard performed.allSatisfy(\.isAttempt) else { return nil }
            return PrescriptionHistoryBasis(
                variationID: variationID,
                mode: mode,
                workingSetValues: nil,
                performedAt: performedAt
            )
        }
    }
}

enum PrescriptionStateError: Error, Equatable {
    case numericEstimateRequired
    case numericEstimateNotSupported
}

enum PrescriptionInitializationResult {
    case ready(ExercisePrescriptionState)
    case calibrationRequired(ExercisePrescriptionState?)
}

@MainActor
enum PrescriptionStateService {
    static func state(
        athleteID: UUID,
        variationID: UUID,
        context: ModelContext
    ) throws -> ExercisePrescriptionState? {
        let key = ExercisePrescriptionState.makeOwnershipKey(
            athleteID: athleteID,
            variationID: variationID
        )
        var descriptor = FetchDescriptor<ExercisePrescriptionState>(
            predicate: #Predicate { $0.ownershipKey == key }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    static func storeEstimate(
        athleteID: UUID,
        variationID: UUID,
        mode: PrescriptionMode,
        values: ThreeWorkingSetValues,
        context: ModelContext,
        now: Date = .now
    ) throws -> ExercisePrescriptionState {
        guard mode == .reps || mode == .duration else {
            throw PrescriptionStateError.numericEstimateNotSupported
        }
        guard values.all.allSatisfy({ $0 > 0 }) else {
            throw PrescriptionStateError.numericEstimateRequired
        }
        if let anchored = try authoritativeRealPerformanceState(
            athleteID: athleteID,
            variationID: variationID,
            context: context,
            asOf: now
        ) {
            return anchored
        }
        return try upsert(
            athleteID: athleteID,
            variationID: variationID,
            mode: mode,
            basisKind: .estimate,
            values: values,
            lastRelevantPerformanceAt: nil,
            context: context,
            now: now
        )
    }

    @discardableResult
    static func storeExploratory(
        athleteID: UUID,
        variationID: UUID,
        mode: PrescriptionMode,
        context: ModelContext,
        now: Date = .now
    ) throws -> ExercisePrescriptionState {
        if let anchored = try authoritativeRealPerformanceState(
            athleteID: athleteID,
            variationID: variationID,
            context: context,
            asOf: now
        ) {
            return anchored
        }
        return try upsert(
            athleteID: athleteID,
            variationID: variationID,
            mode: mode,
            basisKind: .exploratory,
            values: nil,
            lastRelevantPerformanceAt: nil,
            context: context,
            now: now
        )
    }

    static func initializeIfPossible(
        athleteID: UUID,
        variationID: UUID,
        mode: PrescriptionMode,
        context: ModelContext,
        asOf date: Date = .now,
        policy: PrescriptionStalenessPolicy = .v1
    ) throws -> PrescriptionInitializationResult {
        let existing = try state(
            athleteID: athleteID,
            variationID: variationID,
            context: context
        )

        if let existing,
           !existing.hasValidOwnership(
               athleteID: athleteID,
               variationID: variationID
           ) {
            return .calibrationRequired(existing)
        }
        if let existing, existing.basisKind == .realPerformance {
            guard let existingMode = existing.mode,
                  existing.isUsable(for: existingMode) else {
                return .calibrationRequired(existing)
            }
        }

        if let history = try PrescriptionHistoryBootstrap.latestEligibleBasis(
            variationID: variationID,
            mode: mode,
            context: context,
            asOf: date,
            policy: policy
        ), existing?.lastRelevantPerformanceAt == nil
            || history.performedAt > (existing?.lastRelevantPerformanceAt ?? .distantPast) {
            let anchored = try upsert(
                athleteID: athleteID,
                variationID: variationID,
                mode: mode,
                basisKind: .realPerformance,
                values: history.workingSetValues,
                lastRelevantPerformanceAt: history.performedAt,
                context: context,
                now: date
            )
            return .ready(anchored)
        }

        if let existing,
           existing.isUsable(for: mode),
           !existing.requiresRecalibration(asOf: date, policy: policy) {
            return .ready(existing)
        }
        return .calibrationRequired(existing)
    }

    private static func authoritativeRealPerformanceState(
        athleteID: UUID,
        variationID: UUID,
        context: ModelContext,
        asOf date: Date,
        policy: PrescriptionStalenessPolicy = .v1
    ) throws -> ExercisePrescriptionState? {
        guard let existing = try state(
            athleteID: athleteID,
            variationID: variationID,
            context: context
        ), existing.hasValidOwnership(
            athleteID: athleteID,
            variationID: variationID
        ), existing.basisKind == .realPerformance,
           let existingMode = existing.mode,
           existing.isUsable(for: existingMode),
           !existing.requiresRecalibration(asOf: date, policy: policy) else {
            return nil
        }
        return existing
    }

    private static func upsert(
        athleteID: UUID,
        variationID: UUID,
        mode: PrescriptionMode,
        basisKind: PrescriptionBasisKind,
        values: ThreeWorkingSetValues?,
        lastRelevantPerformanceAt: Date?,
        context: ModelContext,
        now: Date
    ) throws -> ExercisePrescriptionState {
        let stored = try state(
            athleteID: athleteID,
            variationID: variationID,
            context: context
        )
        let result = stored ?? ExercisePrescriptionState(
            athleteID: athleteID,
            variationID: variationID,
            mode: mode,
            basisKind: basisKind,
            now: now
        )
        if stored == nil {
            context.insert(result)
        }
        result.modeRaw = mode.rawValue
        result.basisKindRaw = basisKind.rawValue
        result.firstWorkingSetValue = values?.first
        result.secondWorkingSetValue = values?.second
        result.thirdWorkingSetValue = values?.third
        result.lastRelevantPerformanceAt = lastRelevantPerformanceAt
        result.updatedAt = now
        return result
    }
}
