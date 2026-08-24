import Foundation
import SwiftData

enum ExerciseMetric: String, Codable, CaseIterable {
    case reps
    case weightAndReps
    case seconds
}

enum PerformanceSide: String, Codable, CaseIterable {
    case notApplicable
    case left
    case right
}

enum EffortKind: String, Codable, CaseIterable {
    case numeric
    case attempt
}

enum AttemptOutcome: String, Codable, CaseIterable {
    case successful
    case unsuccessful
}

struct NumericTargetSnapshot: Equatable {
    let weight: Double?
    let minReps: Int?
    let maxReps: Int?
    let seconds: Int?
}

struct ActualPerformanceSnapshot: Equatable {
    let weight: Double?
    let reps: Int?
    let seconds: Int?
    let attemptOutcome: AttemptOutcome?
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var metricRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExerciseVariation.exercise)
    var variations: [ExerciseVariation] = []

    var metric: ExerciseMetric {
        get { ExerciseMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    init(name: String, metric: ExerciseMetric) {
        self.id = UUID()
        self.name = name
        self.metricRaw = metric.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class ExerciseVariation {
    @Attribute(.unique) var id: UUID
    var name: String
    var metricRaw: String
    var isLegacyDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var exercise: Exercise?

    var metric: ExerciseMetric {
        get { ExerciseMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    init(
        name: String,
        metric: ExerciseMetric,
        isLegacyDefault: Bool = false,
        exercise: Exercise? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.metricRaw = metric.rawValue
        self.isLegacyDefault = isLegacyDefault
        self.createdAt = .now
        self.updatedAt = .now
        self.exercise = exercise
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplateExercise.template)
    var exercises: [WorkoutTemplateExercise] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class WorkoutTemplateExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var targetSets: Int
    var minReps: Int?
    var maxReps: Int?
    var targetSeconds: Int?
    var exercise: Exercise?
    var template: WorkoutTemplate?

    init(
        orderIndex: Int,
        targetSets: Int,
        minReps: Int? = nil,
        maxReps: Int? = nil,
        targetSeconds: Int? = nil,
        exercise: Exercise? = nil,
        template: WorkoutTemplate? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.minReps = minReps
        self.maxReps = maxReps
        self.targetSeconds = targetSeconds
        self.exercise = exercise
        self.template = template
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var workoutName: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog] = []

    init(workoutName: String) {
        self.id = UUID()
        self.startedAt = .now
        self.workoutName = workoutName
    }
}

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var metricRaw: String = ExerciseMetric.reps.rawValue
    var variationID: UUID?
    var variationName: String?
    var variation: ExerciseVariation?

    var metric: ExerciseMetric {
        get { ExerciseMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    var orderIndex: Int
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog] = []

    init(
        exercise: Exercise,
        variation: ExerciseVariation? = nil,
        orderIndex: Int,
        session: WorkoutSession? = nil
    ) {
        self.id = UUID()
        self.exerciseID = exercise.id
        self.exerciseName = exercise.name
        self.metricRaw = (variation?.metric ?? exercise.metric).rawValue
        self.variationID = variation?.id
        self.variationName = variation?.name
        self.variation = variation
        self.orderIndex = orderIndex
        self.session = session
    }
}

@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var seconds: Int?
    var rir: Int?
    var targetWeight: Double?
    var targetMinReps: Int?
    var targetMaxReps: Int?
    var targetSeconds: Int?
    var sideRaw: String?
    var effortKindRaw: String?
    var attemptOutcomeRaw: String?
    var variationID: UUID?
    var variationName: String?
    var variation: ExerciseVariation?
    var exerciseLog: ExerciseLog?

    var side: PerformanceSide {
        get { sideRaw.flatMap(PerformanceSide.init(rawValue:)) ?? .notApplicable }
        set { sideRaw = newValue.rawValue }
    }

    var effortKind: EffortKind {
        get { effortKindRaw.flatMap(EffortKind.init(rawValue:)) ?? .numeric }
        set { effortKindRaw = newValue.rawValue }
    }

    var attemptOutcome: AttemptOutcome? {
        get { attemptOutcomeRaw.flatMap(AttemptOutcome.init(rawValue:)) }
        set { attemptOutcomeRaw = newValue?.rawValue }
    }

    var hasActualPerformanceEvidence: Bool {
        weight != nil || reps != nil || seconds != nil || attemptOutcome != nil
    }

    var evidenceVariationID: UUID? {
        variationID ?? exerciseLog?.variationID
    }

    var evidenceMetric: ExerciseMetric {
        variation?.metric ?? exerciseLog?.metric ?? .reps
    }

    var isAttempt: Bool {
        effortKind == .attempt
    }

    var targetSnapshot: NumericTargetSnapshot {
        NumericTargetSnapshot(
            weight: targetWeight,
            minReps: targetMinReps,
            maxReps: targetMaxReps,
            seconds: targetSeconds
        )
    }

    var actualSnapshot: ActualPerformanceSnapshot {
        ActualPerformanceSnapshot(
            weight: weight,
            reps: reps,
            seconds: seconds,
            attemptOutcome: attemptOutcome
        )
    }

    init(
        setNumber: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        seconds: Int? = nil,
        rir: Int? = nil,
        targetWeight: Double? = nil,
        targetMinReps: Int? = nil,
        targetMaxReps: Int? = nil,
        targetSeconds: Int? = nil,
        side: PerformanceSide = .notApplicable,
        effortKind: EffortKind = .numeric,
        attemptOutcome: AttemptOutcome? = nil,
        variation: ExerciseVariation? = nil,
        exerciseLog: ExerciseLog? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.seconds = seconds
        self.rir = rir
        self.targetWeight = targetWeight
        self.targetMinReps = targetMinReps
        self.targetMaxReps = targetMaxReps
        self.targetSeconds = targetSeconds
        self.sideRaw = side.rawValue
        self.effortKindRaw = effortKind.rawValue
        self.attemptOutcomeRaw = attemptOutcome?.rawValue
        self.variationID = variation?.id
        self.variationName = variation?.name
        self.variation = variation
        self.exerciseLog = exerciseLog
    }
}

@Model
final class JourneyLevel {
    @Attribute(.unique) var id: UUID
    var number: Int
    var name: String
    var isUnlocked: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LevelRequirement.level)
    var requirements: [LevelRequirement] = []

    @Relationship(deleteRule: .cascade, inverse: \Requirement.journeyLevel)
    var genericRequirements: [Requirement] = []

    init(number: Int, name: String, isUnlocked: Bool = false) {
        self.id = UUID()
        self.number = number
        self.name = name
        self.isUnlocked = isUnlocked
        self.createdAt = .now
        self.updatedAt = .now
    }
}

enum RequirementMetric: String, Codable, CaseIterable {
    case reps
    case seconds
    case weightAndReps
}

@Model
final class LevelRequirement {
    @Attribute(.unique) var id: UUID
    var title: String
    var exerciseID: UUID?
    var metricRaw: String
    var targetReps: Int?
    var targetWeight: Double?
    var targetSeconds: Int?
    var confirmationsNeeded: Int
    var level: JourneyLevel?

    var metric: RequirementMetric {
        get { RequirementMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    init(
        title: String,
        exerciseID: UUID? = nil,
        metric: RequirementMetric,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil,
        confirmationsNeeded: Int = 2,
        level: JourneyLevel? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.exerciseID = exerciseID
        self.metricRaw = metric.rawValue
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetSeconds = targetSeconds
        self.confirmationsNeeded = confirmationsNeeded
        self.level = level
    }
}

@Model
final class Requirement {
    @Attribute(.unique) var id: UUID
    var title: String
    var exerciseID: UUID?
    var metricRaw: String
    var targetReps: Int?
    var targetWeight: Double?
    var targetSeconds: Int?
    var confirmationsNeeded: Int
    var createdAt: Date
    var updatedAt: Date
    var journeyLevel: JourneyLevel?
    var skillStage: SkillStage?

    var metric: RequirementMetric {
        get { RequirementMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    var hasExactlyOneOwner: Bool {
        (journeyLevel != nil) != (skillStage != nil)
    }

    init(
        id: UUID = UUID(),
        title: String,
        exerciseID: UUID? = nil,
        metric: RequirementMetric,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil,
        confirmationsNeeded: Int = 2,
        journeyLevel: JourneyLevel
    ) {
        self.id = id
        self.title = title
        self.exerciseID = exerciseID
        self.metricRaw = metric.rawValue
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetSeconds = targetSeconds
        self.confirmationsNeeded = confirmationsNeeded
        self.createdAt = .now
        self.updatedAt = .now
        self.journeyLevel = journeyLevel
    }

    init(
        id: UUID = UUID(),
        title: String,
        exerciseID: UUID? = nil,
        metric: RequirementMetric,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetSeconds: Int? = nil,
        confirmationsNeeded: Int = 2,
        skillStage: SkillStage
    ) {
        self.id = id
        self.title = title
        self.exerciseID = exerciseID
        self.metricRaw = metric.rawValue
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetSeconds = targetSeconds
        self.confirmationsNeeded = confirmationsNeeded
        self.createdAt = .now
        self.updatedAt = .now
        self.skillStage = skillStage
    }
}

@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var unlockLevel: Int?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SkillStage.skill)
    var stages: [SkillStage] = []

    init(name: String, emoji: String, unlockLevel: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.unlockLevel = unlockLevel
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class SkillStage {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int
    var isCurrent: Bool
    var isCompleted: Bool
    var skill: Skill?

    @Relationship(deleteRule: .cascade, inverse: \Requirement.skillStage)
    var requirements: [Requirement] = []

    init(
        name: String,
        orderIndex: Int,
        isCurrent: Bool = false,
        isCompleted: Bool = false,
        skill: Skill? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self.isCurrent = isCurrent
        self.isCompleted = isCompleted
        self.skill = skill
    }
}
