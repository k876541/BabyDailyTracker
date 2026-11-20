import Foundation
import SwiftData
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("History view model")
struct HistoryViewModelTests {
    @Test("History starts on today and previous day crosses month boundary")
    func initialDateAndPreviousDay() throws {
        let now = date(2026, 1, 1, 12)
        let fixture = try makeFixture(now: now)
        defer { withExtendedLifetime(fixture) {} }
        let viewModel = fixture.viewModel

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: now))

        viewModel.selectPreviousDay()

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: date(2025, 12, 31, 0)))
    }

    @Test("Next day never moves beyond today")
    func nextDayStopsAtToday() throws {
        let now = date(2026, 1, 10, 12)
        let fixture = try makeFixture(now: now)
        defer { withExtendedLifetime(fixture) {} }
        let viewModel = fixture.viewModel

        viewModel.selectNextDay()

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: now))
    }

    @Test("Selecting a future date clamps to today")
    func futureSelectionClampsToToday() throws {
        let now = date(2026, 1, 10, 12)
        let fixture = try makeFixture(now: now)
        defer { withExtendedLifetime(fixture) {} }
        let viewModel = fixture.viewModel

        viewModel.select(date(2026, 2, 1, 12))

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: now))
    }

    @Test("Saving and deleting reloads the selected day summary")
    func saveAndDeleteReloadsSummary() throws {
        let now = date(2026, 1, 10, 12)
        let fixture = try makeFixture(now: now)
        defer { withExtendedLifetime(fixture) {} }
        let viewModel = fixture.viewModel
        viewModel.load()
        let meal = MealRecord(recordedAt: date(2026, 1, 10, 8), kind: "早餐", content: "粥")

        #expect(viewModel.saveMeal(meal))
        #expect(viewModel.dailySummary.mealCount == 1)

        viewModel.delete(meal)

        #expect(viewModel.dailySummary.mealCount == 0)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func makeFixture(now: Date) throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MealRecord.self,
            SleepRecord.self,
            DiaperRecord.self,
            configurations: configuration
        )
        return Fixture(
            container: container,
            viewModel: HistoryViewModel(
                repository: DailyRecordRepository(context: container.mainContext),
                now: { now },
                calendar: calendar
            )
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private struct Fixture {
        let container: ModelContainer
        let viewModel: HistoryViewModel
    }
}
