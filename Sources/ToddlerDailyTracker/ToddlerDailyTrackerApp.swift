import SwiftUI
import SwiftData

@main
struct ToddlerDailyTrackerApp: App {
    private let modelContainer: ModelContainer
#if os(iOS)
    @UIApplicationDelegateAdaptor(MedicationNotificationDelegate.self)
    private var notificationDelegate
#endif

    init() {
        do {
            modelContainer = try ModelContainer(for:
                BabyProfile.self,
                GrowthRecord.self,
                MealRecord.self,
                SleepRecord.self,
                DiaperRecord.self,
                MedicationReminderPlan.self,
                MedicationReminderTimeModel.self,
                MedicationDoseOccurrence.self
            )
#if os(iOS)
            notificationDelegate.configure(container: modelContainer)
#endif
        } catch {
            fatalError("Unable to create app data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
