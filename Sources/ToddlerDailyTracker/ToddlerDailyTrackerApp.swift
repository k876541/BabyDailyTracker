import SwiftUI
import SwiftData

@main
struct ToddlerDailyTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            BabyProfile.self,
            GrowthRecord.self,
            MealRecord.self,
            SleepRecord.self,
            DiaperRecord.self
        ])
    }
}
