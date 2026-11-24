import Foundation

struct DailyHistorySummary: Equatable {
    let mealCount: Int
    let diaperCount: Int
    let sleepDuration: TimeInterval
}

struct WeeklyHistorySummary: Equatable {
    let mealCount: Int
    let diaperCount: Int
    let sleepDuration: TimeInterval
    let recordedDayCount: Int
}

enum HistoryCalculator {
    static func dailySummary(
        meals: [MealRecord],
        sleeps: [SleepRecord],
        diapers: [DiaperRecord],
        day: Date,
        now: Date,
        calendar: Calendar
    ) -> DailyHistorySummary {
        guard let interval = calendar.dateInterval(of: .day, for: day) else {
            return DailyHistorySummary(mealCount: 0, diaperCount: 0, sleepDuration: 0)
        }
        return DailyHistorySummary(
            mealCount: meals.count { interval.contains($0.recordedAt) },
            diaperCount: diapers.count { interval.contains($0.recordedAt) },
            sleepDuration: sleepDuration(sleeps, in: interval, now: now)
        )
    }

    static func weeklySummary(
        meals: [MealRecord],
        sleeps: [SleepRecord],
        diapers: [DiaperRecord],
        endingOn day: Date,
        now: Date,
        calendar: Calendar
    ) -> WeeklyHistorySummary {
        guard
            let endDay = calendar.dateInterval(of: .day, for: day),
            let startDay = calendar.date(byAdding: .day, value: -6, to: endDay.start)
        else {
            return WeeklyHistorySummary(mealCount: 0, diaperCount: 0, sleepDuration: 0, recordedDayCount: 0)
        }
        let interval = DateInterval(start: startDay, end: endDay.end)
        let recordedDayCount = (0..<7).count { offset in
            guard
                let date = calendar.date(byAdding: .day, value: offset, to: interval.start),
                let dayInterval = calendar.dateInterval(of: .day, for: date)
            else { return false }
            return meals.contains { dayInterval.contains($0.recordedAt) }
                || diapers.contains { dayInterval.contains($0.recordedAt) }
                || sleepDuration(sleeps, in: dayInterval, now: now) > 0
        }
        return WeeklyHistorySummary(
            mealCount: meals.count { interval.contains($0.recordedAt) },
            diaperCount: diapers.count { interval.contains($0.recordedAt) },
            sleepDuration: sleepDuration(sleeps, in: interval, now: now),
            recordedDayCount: recordedDayCount
        )
    }

    static func timeline(
        meals: [MealRecord],
        sleeps: [SleepRecord],
        diapers: [DiaperRecord],
        day: Date,
        calendar: Calendar
    ) -> [DailyTimelineItem] {
        DailyTimelineBuilder.build(
            meals: meals,
            sleeps: sleeps,
            diapers: diapers,
            day: day,
            calendar: calendar
        )
    }

    private static func sleepDuration(
        _ sleeps: [SleepRecord],
        in interval: DateInterval,
        now: Date
    ) -> TimeInterval {
        sleeps.reduce(0) { total, sleep in
            let start = max(sleep.startedAt, interval.start)
            let end = min(min(sleep.endedAt ?? now, interval.end), now)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
