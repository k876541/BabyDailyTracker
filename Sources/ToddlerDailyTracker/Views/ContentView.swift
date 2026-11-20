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
        .tint(BabyTheme.primary)
    }
}

enum BabyTheme {
    static let primary = Color(red: 0.91, green: 0.48, blue: 0.36)
    static let peach = Color(red: 1.00, green: 0.91, blue: 0.85)
    static let mint = Color(red: 0.82, green: 0.94, blue: 0.88)
    static let lavender = Color(red: 0.89, green: 0.87, blue: 0.97)
    static let sky = Color(red: 0.84, green: 0.92, blue: 0.98)
}

