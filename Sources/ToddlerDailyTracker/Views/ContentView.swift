import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            NavigationStack { TodayView(context: context) }
                .tabItem { Label("日常", systemImage: "list.bullet.clipboard") }
            NavigationStack { GrowthScreen(context: context) }
                .tabItem { Label("成長", systemImage: "chart.xyaxis.line") }
        }
    }
}

