import Foundation

struct MedicationReminderTime: Hashable, Codable, Sendable {
    let hour: Int
    let minute: Int
}

struct MedicationReminderDraft: Equatable, Sendable {
    var startDate: Date
    var durationDays: Int
    var times: [MedicationReminderTime]
    var minimumIntervalMinutes: Int
    var snoozeMinutes: Int
}

enum MedicationScheduleValidationError: Error, Equatable {
    case invalidDuration
    case noReminderTimes
    case invalidTime
    case duplicateTime
    case unsupportedMinimumInterval
    case invalidSnooze
    case intervalTooShort(requiredMinutes: Int)
    case tooManyOccurrences(maximum: Int)
    case invalidCalendarDate
}

enum MedicationScheduleBuilder {
    static let maximumOccurrences = 48

    static func occurrenceDates(
        for draft: MedicationReminderDraft,
        calendar: Calendar
    ) throws -> [Date] {
        guard draft.durationDays > 0 else {
            throw MedicationScheduleValidationError.invalidDuration
        }
        guard !draft.times.isEmpty else {
            throw MedicationScheduleValidationError.noReminderTimes
        }
        guard draft.times.allSatisfy({ (0..<24).contains($0.hour) && (0..<60).contains($0.minute) }) else {
            throw MedicationScheduleValidationError.invalidTime
        }
        guard Set(draft.times).count == draft.times.count else {
            throw MedicationScheduleValidationError.duplicateTime
        }
        guard draft.minimumIntervalMinutes == 240 || draft.minimumIntervalMinutes == 300 else {
            throw MedicationScheduleValidationError.unsupportedMinimumInterval
        }
        guard draft.snoozeMinutes > 0 else {
            throw MedicationScheduleValidationError.invalidSnooze
        }
        guard draft.times.count <= maximumOccurrences / draft.durationDays else {
            throw MedicationScheduleValidationError.tooManyOccurrences(maximum: maximumOccurrences)
        }

        let startOfFirstDay = calendar.startOfDay(for: draft.startDate)
        var dates: [Date] = []
        dates.reserveCapacity(draft.durationDays * draft.times.count)

        for dayOffset in 0..<draft.durationDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfFirstDay) else {
                throw MedicationScheduleValidationError.invalidCalendarDate
            }
            for time in draft.times {
                guard let date = calendar.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: day
                ) else {
                    throw MedicationScheduleValidationError.invalidCalendarDate
                }
                dates.append(date)
            }
        }

        dates.sort()
        for (previous, next) in zip(dates, dates.dropFirst()) {
            let intervalMinutes = next.timeIntervalSince(previous) / 60
            guard intervalMinutes >= Double(draft.minimumIntervalMinutes) else {
                throw MedicationScheduleValidationError.intervalTooShort(
                    requiredMinutes: draft.minimumIntervalMinutes
                )
            }
        }
        return dates
    }
}
