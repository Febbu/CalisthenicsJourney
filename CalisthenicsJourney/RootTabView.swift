import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                JourneyView()
            }
            .tabItem {
                Label("Journey", systemImage: "gamecontroller.fill")
            }

            NavigationStack {
                WorkoutHomeView()
            }
            .tabItem {
                Label("Workout", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                SkillsView()
            }
            .tabItem {
                Label("Skills", systemImage: "point.3.connected.trianglepath.dotted")
            }
        }
    }
}
