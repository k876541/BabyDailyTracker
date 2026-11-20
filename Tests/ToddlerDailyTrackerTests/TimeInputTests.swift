import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("Record time input")
struct TimeInputTests {
    @Test("Quick time rounds to the nearest five minutes")
    func quickTimeRoundsToNearestFiveMinutes() {
        #expect(components(TimeInput.roundedToFiveMinutes(date(2026, 1, 10, 9, 17))) == [2026, 1, 10, 9, 15])
        #expect(components(TimeInput.roundedToFiveMinutes(date(2026, 1, 10, 9, 18))) == [2026, 1, 10, 9, 20])
    }

    @Test("Rounding near midnight rolls into the next day")
    func roundingNearMidnightRollsToNextDay() {
        let rounded = TimeInput.roundedToFiveMinutes(date(2026, 1, 10, 23, 58))

        #expect(components(rounded) == [2026, 1, 11, 0, 0])
    }

    @Test("Exact time accepts any valid minute and preserves the date")
    func exactTimeAcceptsAnyValidMinute() {
        let parsed = TimeInput.parseExact("09:17", on: date(2026, 1, 10, 14, 30), calendar: calendar)

        #expect(parsed.map(components) == [2026, 1, 10, 9, 17])
    }

    @Test(arguments: ["9:17", "24:00", "12:60", "", "ab:cd"])
    func exactTimeRejectsInvalidInput(_ input: String) {
        #expect(TimeInput.parseExact(input, on: date(2026, 1, 10, 14, 30), calendar: calendar) == nil)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func components(_ date: Date) -> [Int] {
        let value = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [value.year!, value.month!, value.day!, value.hour!, value.minute!]
    }
}
