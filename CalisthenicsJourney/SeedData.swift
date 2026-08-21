import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func installIfNeeded(context: ModelContext, existingExerciseCount: Int) {
        guard existingExerciseCount == 0 else {
            try? RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
            try? context.save()
            return
        }

        let pushups = Exercise(name: "Push-ups", metric: .reps)
        let pulldown = Exercise(name: "Lat Pulldown", metric: .weightAndReps)
        let shoulderPress = Exercise(name: "Shoulder Press", metric: .weightAndReps)
        let row = Exercise(name: "Seated Cable Row", metric: .weightAndReps)
        let legPress = Exercise(name: "Leg Press / Squat", metric: .weightAndReps)
        let rdl = Exercise(name: "DB Romanian Deadlift", metric: .weightAndReps)
        let hollow = Exercise(name: "Hollow Body Hold", metric: .seconds)
        let handstand = Exercise(name: "Wall Handstand", metric: .seconds)

        [pushups, pulldown, shoulderPress, row, legPress, rdl, hollow, handstand]
            .forEach(context.insert)

        let workout = WorkoutTemplate(name: "Foundation Workout")
        context.insert(workout)

        let templateExercises = [
            WorkoutTemplateExercise(orderIndex: 0, targetSets: 3, targetSeconds: 30, exercise: handstand, template: workout),
            WorkoutTemplateExercise(orderIndex: 1, targetSets: 3, minReps: 8, maxReps: 15, exercise: pushups, template: workout),
            WorkoutTemplateExercise(orderIndex: 2, targetSets: 3, minReps: 8, maxReps: 12, exercise: pulldown, template: workout),
            WorkoutTemplateExercise(orderIndex: 3, targetSets: 3, minReps: 8, maxReps: 12, exercise: shoulderPress, template: workout),
            WorkoutTemplateExercise(orderIndex: 4, targetSets: 3, minReps: 8, maxReps: 12, exercise: row, template: workout),
            WorkoutTemplateExercise(orderIndex: 5, targetSets: 3, minReps: 8, maxReps: 12, exercise: legPress, template: workout),
            WorkoutTemplateExercise(orderIndex: 6, targetSets: 2, minReps: 8, maxReps: 12, exercise: rdl, template: workout),
            WorkoutTemplateExercise(orderIndex: 7, targetSets: 3, targetSeconds: 30, exercise: hollow, template: workout)
        ]

        templateExercises.forEach(context.insert)
        workout.exercises = templateExercises

        let level1 = JourneyLevel(number: 1, name: "Foundation", isUnlocked: true)
        context.insert(level1)

        let requirements = [
            Requirement(
                title: "20 clean push-ups",
                exerciseID: pushups.id,
                metric: .reps,
                targetReps: 20,
                confirmationsNeeded: 2,
                journeyLevel: level1
            ),
            Requirement(
                title: "30s controlled wall handstand",
                exerciseID: handstand.id,
                metric: .seconds,
                targetSeconds: 30,
                confirmationsNeeded: 2,
                journeyLevel: level1
            ),
            Requirement(
                title: "30s hollow-body hold",
                exerciseID: hollow.id,
                metric: .seconds,
                targetSeconds: 30,
                confirmationsNeeded: 2,
                journeyLevel: level1
            )
        ]

        requirements.forEach(context.insert)
        level1.genericRequirements = requirements

        let handstandSkill = Skill(name: "Handstand", emoji: "🤸")
        context.insert(handstandSkill)

        let handstandStages = [
            SkillStage(name: "Wrist / shoulder preparation", orderIndex: 0, isCompleted: true, skill: handstandSkill),
            SkillStage(name: "Wall Handstand — 30s ×2", orderIndex: 1, isCurrent: true, skill: handstandSkill),
            SkillStage(name: "Wall Balance Drills", orderIndex: 2, skill: handstandSkill),
            SkillStage(name: "Freestanding Attempts", orderIndex: 3, skill: handstandSkill),
            SkillStage(name: "5s Freestanding", orderIndex: 4, skill: handstandSkill),
            SkillStage(name: "15s Freestanding", orderIndex: 5, skill: handstandSkill),
            SkillStage(name: "30s Freestanding", orderIndex: 6, skill: handstandSkill)
        ]
        handstandStages.forEach(context.insert)
        handstandSkill.stages = handstandStages

        let pullup = Skill(name: "Pull-up", emoji: "🪽")
        let lSit = Skill(name: "L-Sit", emoji: "🧘")
        let dips = Skill(name: "Dips", emoji: "💪", unlockLevel: 2)
        let muscleUp = Skill(name: "Muscle-up", emoji: "🚀", unlockLevel: 4)
        [pullup, lSit, dips, muscleUp].forEach(context.insert)

        try? context.save()
        try? RequirementMigration.migrateLegacyRequirementsIfNeeded(context: context)
        try? context.save()
    }
}
