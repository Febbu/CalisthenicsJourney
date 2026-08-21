import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
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
