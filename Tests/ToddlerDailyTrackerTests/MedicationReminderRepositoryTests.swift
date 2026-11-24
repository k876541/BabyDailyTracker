import Foundation
import SwiftData
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Medication reminder repository")
struct MedicationReminderRepositoryTests {
    @Test("Create stores one active plan and all occurrences")
    func createStoresOneActivePlanAndOccurrences() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9), date(13), date(17)])

        #expect(plan.isActive)
        #expect(plan.times.map(\.hour).sorted() == [9, 13, 17])
        #expect(plan.occurrences.map(\.scheduledAt).sorted() == [date(9), date(13), date(17)])
        #expect(try fixture.repository.activePlan()?.id == plan.id)
    }

    @Test("A second active plan is rejected")
    func secondActivePlanIsRejected() throws {
        let fixture = try makeFixture()
        _ = try fixture.repository.create(draft: draft(), dates: [date(9)])

        #expect(throws: MedicationReminderRepositoryError.activePlanAlreadyExists) {
            try fixture.repository.create(draft: draft(), dates: [date(13)])
        }
    }

    @Test("Replacing a plan updates its settings and occurrence graph")
    func replaceUpdatesPlanAndOccurrenceGraph() throws {
        let fixture = try makeFixture()
        let original = try fixture.repository.create(draft: draft(), dates: [date(9), date(13), date(17)])
        let replacement = MedicationReminderDraft(
            startDate: day,
            durationDays: 2,
            times: [MedicationReminderTime(hour: 8, minute: 0), MedicationReminderTime(hour: 20, minute: 0)],
            minimumIntervalMinutes: 300,
            snoozeMinutes: 10
        )

        let plan = try fixture.repository.replace(
            planID: original.id,
            draft: replacement,
            dates: [date(8), date(20), date(8, dayOffset: 1), date(20, dayOffset: 1)]
        )

        #expect(plan.id == original.id)
        #expect(plan.durationDays == 2)
        #expect(plan.minimumIntervalMinutes == 300)
        #expect(plan.snoozeMinutes == 10)
        #expect(plan.times.map(\.hour).sorted() == [8, 20])
        #expect(plan.occurrences.count == 4)
    }

    @Test("Replacing a plan preserves completed occurrences")
    func replacePreservesCompletedOccurrences() throws {
        let fixture = try makeFixture()
        let original = try fixture.repository.create(draft: draft(), dates: [date(9), date(13)])
        let completed = try #require(original.occurrences.first { $0.scheduledAt == date(9) })
        try fixture.repository.complete(occurrenceID: completed.id, at: date(9, minute: 20))

        let updated = try fixture.repository.replace(
            planID: original.id,
            draft: draft(),
            dates: [date(17)]
        )

        #expect(updated.occurrences.map(\.id).contains(completed.id))
        #expect(updated.occurrences.first { $0.id == completed.id }?.completedAt == date(9, minute: 20))
        #expect(updated.occurrences.map(\.scheduledAt).sorted() == [date(9), date(17)])
    }

    @Test("Today occurrences are chronological")
    func todayOccurrencesAreChronological() throws {
        let fixture = try makeFixture()
        _ = try fixture.repository.create(draft: draft(), dates: [date(17), date(9), date(13)])

        let occurrences = try fixture.repository.occurrences(on: day, calendar: calendar)

        #expect(occurrences.map(\.scheduledAt) == [date(9), date(13), date(17)])
    }

    @Test("Today occurrences exclude inactive plans")
    func todayOccurrencesExcludeInactivePlans() throws {
        let fixture = try makeFixture()
        let oldPlan = try fixture.repository.create(draft: draft(), dates: [date(9)])
        try fixture.repository.end(planID: oldPlan.id, at: date(10))
        let newPlan = try fixture.repository.create(draft: draft(), dates: [date(13)])

        let occurrences = try fixture.repository.occurrences(on: day, calendar: calendar)

        #expect(occurrences.map(\.id) == newPlan.occurrences.map(\.id))
    }

    @Test("Completing stores actual completion time")
    func completeStoresActualTime() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9)])
        let occurrence = try #require(plan.occurrences.first)
        let actual = date(9, minute: 22)

        try fixture.repository.complete(occurrenceID: occurrence.id, at: actual)

        #expect(occurrence.status == .completed)
        #expect(occurrence.completedAt == actual)
        #expect(occurrence.nextReminderAt == nil)
    }

    @Test("Completing twice preserves the first actual time")
    func completingTwicePreservesFirstTime() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9)])
        let occurrence = try #require(plan.occurrences.first)
        let first = date(9, minute: 22)

        try fixture.repository.complete(occurrenceID: occurrence.id, at: first)
        try fixture.repository.complete(occurrenceID: occurrence.id, at: date(9, minute: 45))

        #expect(occurrence.completedAt == first)
    }

    @Test("Snoozing stores only the latest reminder time")
    func snoozeStoresOnlyLatestReminderTime() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9)])
        let occurrence = try #require(plan.occurrences.first)

        try fixture.repository.snooze(occurrenceID: occurrence.id, until: date(9, minute: 5))
        try fixture.repository.snooze(occurrenceID: occurrence.id, until: date(9, minute: 10))

        #expect(occurrence.status == .snoozed)
        #expect(occurrence.nextReminderAt == date(9, minute: 10))
        #expect(occurrence.snoozeCount == 2)
    }

    @Test("Ending a plan marks unfinished occurrences skipped")
    func endMarksPendingOccurrencesSkipped() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9), date(13)])
        let completed = try #require(plan.occurrences.first { $0.scheduledAt == date(9) })
        try fixture.repository.complete(occurrenceID: completed.id, at: date(9))

        try fixture.repository.end(planID: plan.id, at: date(10))

        #expect(!plan.isActive)
        #expect(plan.endedAt == date(10))
        #expect(completed.status == .completed)
        #expect(plan.occurrences.first { $0.scheduledAt == date(13) }?.status == .skipped)
    }

    @Test("Deleting removes the plan graph")
    func deleteRemovesThePlanGraph() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9), date(13)])

        try fixture.repository.delete(planID: plan.id)

        #expect(try fixture.container.mainContext.fetch(FetchDescriptor<MedicationReminderPlan>()).isEmpty)
        #expect(try fixture.container.mainContext.fetch(FetchDescriptor<MedicationReminderTimeModel>()).isEmpty)
        #expect(try fixture.container.mainContext.fetch(FetchDescriptor<MedicationDoseOccurrence>()).isEmpty)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
    }

    private func draft() -> MedicationReminderDraft {
        MedicationReminderDraft(
            startDate: day,
            durationDays: 1,
            times: [MedicationReminderTime(hour: 9, minute: 0), MedicationReminderTime(hour: 13, minute: 0), MedicationReminderTime(hour: 17, minute: 0)],
            minimumIntervalMinutes: 240,
            snoozeMinutes: 5
        )
    }

    private func date(_ hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: dayOffset, to: day)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func makeFixture() throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MedicationReminderPlan.self,
            MedicationReminderTimeModel.self,
            MedicationDoseOccurrence.self,
            configurations: configuration
        )
        return Fixture(
            container: container,
            repository: SwiftDataMedicationReminderRepository(context: container.mainContext)
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let repository: SwiftDataMedicationReminderRepository
    }
}
