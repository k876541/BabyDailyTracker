import Foundation
import SwiftData
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("App data reset repository")
struct AppDataResetRepositoryTests {
    @Test("Reset removes every local model and returns medication occurrence IDs")
    func resetRemovesEveryModelAndReturnsOccurrenceIDs() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let occurrenceID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let plan = MedicationReminderPlan(
            startDate: .now,
            durationDays: 1,
            minimumIntervalMinutes: 240,
            snoozeMinutes: 5
        )
        plan.times = [MedicationReminderTimeModel(hour: 13, minute: 0, plan: plan)]
        plan.occurrences = [MedicationDoseOccurrence(id: occurrenceID, scheduledAt: .now, plan: plan)]
        context.insert(BabyProfile(name: "小安", birthday: .now))
        context.insert(GrowthRecord(measuredAt: .now, heightCM: 80))
        context.insert(MealRecord(recordedAt: .now, kind: "正餐", content: "粥"))
        context.insert(SleepRecord(startedAt: .now))
        context.insert(DiaperRecord(recordedAt: .now, condition: "正常"))
        context.insert(plan)
        try context.save()

        let ids = try SwiftDataAppDataResetRepository(context: context).reset()

        #expect(ids == [occurrenceID])
        #expect(try context.fetch(FetchDescriptor<BabyProfile>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GrowthRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MealRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SleepRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DiaperRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MedicationReminderPlan>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MedicationReminderTimeModel>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MedicationDoseOccurrence>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BabyProfile.self,
            GrowthRecord.self,
            MealRecord.self,
            SleepRecord.self,
            DiaperRecord.self,
            MedicationReminderPlan.self,
            MedicationReminderTimeModel.self,
            MedicationDoseOccurrence.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
