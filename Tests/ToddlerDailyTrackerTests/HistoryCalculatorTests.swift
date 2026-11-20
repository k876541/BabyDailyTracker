import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("History summary")
struct HistoryCalculatorTests {
    @Test("Daily summary counts only records on the selected day")
    func dailySummaryFiltersBySelectedDay() {
        let calendar = utcCalendar
        let selectedDay = date(2026, 1, 10, 12)
        let meals = [
            MealRecord(recordedAt: date(2026, 1, 10, 8), kind: "奶", content: "配方奶"),
            MealRecord(recordedAt: date(2026, 1, 9, 8), kind: "正餐", content: "粥")
        ]
        let diapers = [
            DiaperRecord(recordedAt: date(2026, 1, 10, 9), condition: "正常"),
            DiaperRecord(recordedAt: date(2026, 1, 11, 9), condition: "正常")
        ]

        let summary = HistoryCalculator.dailySummary(
            meals: meals,
            sleeps: [],
            diapers: diapers,
            day: selectedDay,
            now: date(2026, 1, 10, 18),
            calendar: calendar
        )

        #expect(summary.mealCount == 1)
        #expect(summary.diaperCount == 1)
    }

    @Test("Sleep crossing midnight is split at calendar day boundaries")
    func crossMidnightSleepIsSplitByDay() {
        let sleep = SleepRecord(
            startedAt: date(2026, 1, 9, 22),
            endedAt: date(2026, 1, 10, 2)
        )

        let januaryTenth = HistoryCalculator.dailySummary(
            meals: [],
            sleeps: [sleep],
            diapers: [],
            day: date(2026, 1, 10, 12),
            now: date(2026, 1, 10, 12),
            calendar: utcCalendar
        )

        #expect(januaryTenth.sleepDuration == 2 * 60 * 60)
    }

    @Test("Active and future sleep never produces negative duration")
    func activeAndFutureSleepNeverProducesNegativeDuration() {
        let sleeps = [
            SleepRecord(startedAt: date(2026, 1, 10, 10)),
            SleepRecord(startedAt: date(2026, 1, 10, 15))
        ]

        let summary = HistoryCalculator.dailySummary(
            meals: [],
            sleeps: sleeps,
            diapers: [],
            day: date(2026, 1, 10, 12),
            now: date(2026, 1, 10, 12),
            calendar: utcCalendar
        )

        #expect(summary.sleepDuration == 2 * 60 * 60)
    }

    @Test("Weekly summary includes selected day and previous six calendar days")
    func weeklySummaryUsesSevenCalendarDays() {
        let meals = [
            MealRecord(recordedAt: date(2026, 1, 1, 8), kind: "正餐", content: "太早"),
            MealRecord(recordedAt: date(2026, 1, 2, 8), kind: "正餐", content: "範圍起點"),
            MealRecord(recordedAt: date(2026, 1, 8, 8), kind: "正餐", content: "選定日")
        ]
        let sleeps = [SleepRecord(startedAt: date(2026, 1, 1, 23), endedAt: date(2026, 1, 2, 1))]

        let summary = HistoryCalculator.weeklySummary(
            meals: meals,
            sleeps: sleeps,
            diapers: [],
            endingOn: date(2026, 1, 8, 12),
            now: date(2026, 1, 8, 18),
            calendar: utcCalendar
        )

        #expect(summary.mealCount == 2)
        #expect(summary.sleepDuration == 60 * 60)
        #expect(summary.recordedDayCount == 2)
    }

    @Test("Daily boundary follows the calendar time zone")
    func dailyBoundaryUsesCalendarTimeZone() {
        var taipei = Calendar(identifier: .gregorian)
        taipei.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let recordAtSevenThirtyAM = Date(timeIntervalSince1970: 1_767_291_000)
        let meal = MealRecord(recordedAt: recordAtSevenThirtyAM, kind: "早餐", content: "粥")

        let summary = HistoryCalculator.dailySummary(
            meals: [meal],
            sleeps: [],
            diapers: [],
            day: date(2026, 1, 2, 12, calendar: taipei),
            now: date(2026, 1, 2, 18, calendar: taipei),
            calendar: taipei
        )

        #expect(summary.mealCount == 1)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar? = nil
    ) -> Date {
        (calendar ?? utcCalendar).date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
