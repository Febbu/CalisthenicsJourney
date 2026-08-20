import Foundation
import SwiftData

enum ExerciseMetric: String, Codable, CaseIterable {
    case reps
    case weightAndReps
    case seconds
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var metricRaw: String
    var createdAt: Date
    var updatedAt: Date

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

    var metric: ExerciseMetric {
        get { ExerciseMetric(rawValue: metricRaw) ?? .reps }
        set { metricRaw = newValue.rawValue }
    }

    var orderIndex: Int
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog] = []

    init(exercise: Exercise, orderIndex: Int, session: WorkoutSession? = nil) {
        self.id = UUID()
        self.exerciseID = exercise.id
        self.exerciseName = exercise.name
        self.metricRaw = exercise.metric.rawValue
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
    var exerciseLog: ExerciseLog?

    init(
        setNumber: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        seconds: Int? = nil,
        rir: Int? = nil,
        exerciseLog: ExerciseLog? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.seconds = seconds
        self.rir = rir
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
