import SwiftUI
import SwiftData

@main
struct CalisthenicsJourneyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            Exercise.self,
            ExerciseVariation.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            WorkoutSession.self,
            ExerciseLog.self,
            SetLog.self,
            JourneyLevel.self,
            LevelRequirement.self,
            Requirement.self,
            RequirementImplication.self,
            Skill.self,
            SkillStage.self
        ])
    }
}
