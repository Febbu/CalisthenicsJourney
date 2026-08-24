import Foundation
import SwiftData

@MainActor
enum EvidenceMigration {
    static func defaultVariation(for exercise: Exercise, context: ModelContext) -> ExerciseVariation {
        if let existing = exercise.variations.first(where: \.isLegacyDefault) {
            return existing
        }

        let variation = ExerciseVariation(
            name: exercise.name,
            metric: exercise.metric,
            isLegacyDefault: true,
            exercise: exercise
        )
        context.insert(variation)
        exercise.variations.append(variation)
        return variation
    }

    static func migrateLegacyExerciseEvidenceIfNeeded(context: ModelContext) throws {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let existingVariations = try context.fetch(FetchDescriptor<ExerciseVariation>())
        let logs = try context.fetch(FetchDescriptor<ExerciseLog>())

        var exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        var defaultVariationsByExerciseID: [UUID: ExerciseVariation] = [:]

        for variation in existingVariations where variation.isLegacyDefault {
            if let exerciseID = variation.exercise?.id,
               defaultVariationsByExerciseID[exerciseID] == nil {
                defaultVariationsByExerciseID[exerciseID] = variation
            }
        }

        func migratedDefaultVariation(for exercise: Exercise) -> ExerciseVariation {
            if let existing = defaultVariationsByExerciseID[exercise.id] {
                return existing
            }

            let variation = defaultVariation(for: exercise, context: context)
            defaultVariationsByExerciseID[exercise.id] = variation
            return variation
        }

        for exercise in exercises {
            _ = migratedDefaultVariation(for: exercise)
        }

        for log in logs {
            let exercise: Exercise
            if let existing = exercisesByID[log.exerciseID] {
                exercise = existing
            } else {
                let recovered = Exercise(name: log.exerciseName, metric: log.metric)
                recovered.id = log.exerciseID
                context.insert(recovered)
                exercisesByID[recovered.id] = recovered
                exercise = recovered
            }

            let variation = migratedDefaultVariation(for: exercise)
            if log.variationID == nil {
                log.variation = variation
                log.variationID = variation.id
                log.variationName = variation.name
            }

            for set in log.sets where set.variationID == nil {
                set.variation = variation
                set.variationID = variation.id
                set.variationName = variation.name
            }
        }
    }
}
