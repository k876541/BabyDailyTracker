import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("Medication schedule")
struct MedicationScheduleTests {
    @Test("Empty times are rejected")
    func emptyTimesAreRejected() {
        #expect(throws: MedicationScheduleValidationError.noReminderTimes) {
            try MedicationScheduleBuilder.occurrenceDates(for: draft(times: []), calendar: calendar)
        }
    }

    @Test("Duplicate times are rejected")
    func duplicateTimesAreRejected() {
        let time = MedicationReminderTime(hour: 9, minute: 0)
        #expect(throws: MedicationScheduleValidationError.duplicateTime) {
            try MedicationScheduleBuilder.occurrenceDates(for: draft(times: [time, time]), calendar: calendar)
        }
    }

    @Test("A non-positive duration is rejected")
    func invalidDurationIsRejected() {
        #expect(throws: MedicationScheduleValidationError.invalidDuration) {
            try MedicationScheduleBuilder.occurrenceDates(for: draft(durationDays: 0), calendar: calendar)
        }
    }

    @Test("Only four or five hour minimum intervals are accepted")
    func invalidMinimumIntervalIsRejected() {
        #expect(throws: MedicationScheduleValidationError.unsupportedMinimumInterval) {
            try MedicationScheduleBuilder.occurrenceDates(
                for: draft(minimumIntervalMinutes: 180),
                calendar: calendar
            )
        }
    }

    @Test("A non-positive snooze is rejected")
    func invalidSnoozeIsRejected() {
        #expect(throws: MedicationScheduleValidationError.invalidSnooze) {
            try MedicationScheduleBuilder.occurrenceDates(for: draft(snoozeMinutes: 0), calendar: calendar)
        }
    }

    @Test("An invalid clock time is rejected")
    func invalidTimeIsRejected() {
        #expect(throws: MedicationScheduleValidationError.invalidTime) {
            try MedicationScheduleBuilder.occurrenceDates(
                for: draft(times: [MedicationReminderTime(hour: 24, minute: 0)]),
                calendar: calendar
            )
        }
    }

    @Test("A cross-day gap below the minimum is rejected")
    func crossDayGapBelowMinimumIsRejected() {
        #expect(throws: MedicationScheduleValidationError.intervalTooShort(requiredMinutes: 240)) {
            try MedicationScheduleBuilder.occurrenceDates(
                for: draft(
                    durationDays: 2,
                    times: [time(1), time(22)],
                    minimumIntervalMinutes: 240
                ),
                calendar: calendar
            )
        }
    }

    @Test("An exact four-hour cross-day gap is accepted")
    func exactFourHourGapIsAccepted() throws {
        let dates = try MedicationScheduleBuilder.occurrenceDates(
            for: draft(
                durationDays: 2,
                times: [time(1), time(21)],
                minimumIntervalMinutes: 240
            ),
            calendar: calendar
        )

        #expect(dates.count == 4)
    }

    @Test("An exact five-hour cross-day gap is accepted")
    func exactFiveHourGapIsAccepted() throws {
        let dates = try MedicationScheduleBuilder.occurrenceDates(
            for: draft(
                durationDays: 2,
                times: [time(1), time(20)],
                minimumIntervalMinutes: 300
            ),
            calendar: calendar
        )

        #expect(dates.count == 4)
    }

    @Test("More than forty-eight occurrences are rejected")
    func moreThanFortyEightOccurrencesIsRejected() {
        #expect(throws: MedicationScheduleValidationError.tooManyOccurrences(maximum: 48)) {
            try MedicationScheduleBuilder.occurrenceDates(
                for: draft(durationDays: 25, times: [time(8), time(20)]),
                calendar: calendar
            )
        }
    }

    @Test("Occurrences are chronological even when input times are not")
    func occurrencesAreChronological() throws {
        let dates = try MedicationScheduleBuilder.occurrenceDates(
            for: draft(times: [time(17), time(9), time(13)]),
            calendar: calendar
        )

        #expect(dates == [date(2026, 11, 23, 9), date(2026, 11, 23, 13), date(2026, 11, 23, 17)])
    }

    @Test("Time mutations remain valid after reordering and deletion")
    func timeMutationsUseStableIdentity() {
        var value = draft(times: [time(9), time(13), time(17)])
        let selectedID = value.times[0].id

        value.updateTime(id: selectedID, hour: 18, minute: 0)

        #expect(value.times.map(\.hour) == [13, 17, 18])
        #expect(value.times.last?.id == selectedID)

        value.removeTime(id: selectedID)

        #expect(value.times.map(\.hour) == [13, 17])
        #expect(value.times.allSatisfy { $0.id != selectedID })
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func draft(
        durationDays: Int = 1,
        times: [MedicationReminderTime] = [MedicationReminderTime(hour: 9, minute: 0)],
        minimumIntervalMinutes: Int = 240,
        snoozeMinutes: Int = 5
    ) -> MedicationReminderDraft {
        MedicationReminderDraft(
            startDate: date(2026, 11, 23, 12),
            durationDays: durationDays,
            times: times,
            minimumIntervalMinutes: minimumIntervalMinutes,
            snoozeMinutes: snoozeMinutes
        )
    }

    private func time(_ hour: Int) -> MedicationReminderTime {
        MedicationReminderTime(hour: hour, minute: 0)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
