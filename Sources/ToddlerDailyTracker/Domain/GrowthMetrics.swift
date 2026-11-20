import Foundation
import SwiftData

enum GrowthValidationError: Error, Equatable {
    case missingMeasurement
    case invalidHeight
    case invalidWeight
}

enum GrowthInputValidator {
    static func validate(height: Double?, weight: Double?) throws {
        guard height != nil || weight != nil else {
            throw GrowthValidationError.missingMeasurement
        }
        if let height, !height.isFinite || height <= 0 {
            throw GrowthValidationError.invalidHeight
        }
        if let weight, !weight.isFinite || weight <= 0 {
            throw GrowthValidationError.invalidWeight
        }
    }
}

enum GrowthInputParser {
    static func parse(heightText: String, weightText: String) throws -> (height: Double?, weight: Double?) {
        let height = try parse(heightText, error: .invalidHeight)
        let weight = try parse(weightText, error: .invalidWeight)
        try GrowthInputValidator.validate(height: height, weight: weight)
        return (height, weight)
    }

    private static func parse(_ text: String, error: GrowthValidationError) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed) else { throw error }
        return value
    }
}

enum GrowthMetric: String, CaseIterable, Identifiable {
    case height = "身高"
    case weight = "體重"

    var id: Self { self }
    var unit: String { self == .height ? "cm" : "kg" }
}

struct GrowthSample: Equatable {
    let measuredAt: Date
    let heightCM: Double?
    let weightKG: Double?

    func value(for metric: GrowthMetric) -> Double? {
        metric == .height ? heightCM : weightKG
    }
}

struct GrowthPoint: Equatable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct GrowthSummary: Equatable {
    let latest: Double
    let change: Double?
    let measuredAt: Date
}

enum GrowthMetrics {
    static func trend(for metric: GrowthMetric, samples: [GrowthSample]) -> [GrowthPoint] {
        samples.compactMap { sample in
            guard let value = sample.value(for: metric), value.isFinite, value > 0 else { return nil }
            return GrowthPoint(date: sample.measuredAt, value: value)
        }
        .sorted { $0.date < $1.date }
    }

    static func summary(for metric: GrowthMetric, samples: [GrowthSample]) -> GrowthSummary? {
        let points = trend(for: metric, samples: samples)
        guard let latest = points.last else { return nil }
        let change = points.count > 1 ? latest.value - points[points.count - 2].value : nil
        return GrowthSummary(latest: latest.value, change: change, measuredAt: latest.date)
    }
}

enum DailyRecordValidationError: Error, Equatable {
    case invalidSleepRange
    case invalidMealAmount
    case sleepAlreadyInProgress
    case noSleepInProgress
}

enum DailyRecordValidator {
    static func validateSleep(start: Date, end: Date) throws {
        guard end >= start else { throw DailyRecordValidationError.invalidSleepRange }
    }

    static func validateMealAmount(_ amount: Double?) throws {
        guard let amount else { return }
        guard amount.isFinite, amount > 0 else { throw DailyRecordValidationError.invalidMealAmount }
    }

    static func validateCanStartSleep(records: [SleepRecord]) throws {
        guard !records.contains(where: { $0.endedAt == nil }) else {
            throw DailyRecordValidationError.sleepAlreadyInProgress
        }
    }
}

enum DailyTimelineKind: Equatable {
    case meal
    case sleep
    case diaper
}

enum DailyTimelineSource: Hashable {
    case meal(PersistentIdentifier)
    case sleep(PersistentIdentifier)
    case diaper(PersistentIdentifier)
}

struct DailyTimelineItem: Identifiable {
    let id: DailyTimelineSource
    let kind: DailyTimelineKind
    let eventDate: Date
    let title: String
    let detail: String
}

enum DailyTimelineBuilder {
    static func build(
        meals: [MealRecord],
        sleeps: [SleepRecord],
        diapers: [DiaperRecord],
        day: Date? = nil,
        calendar: Calendar = .current
    ) -> [DailyTimelineItem] {
        let mealItems = meals.map { meal in
            let amount = meal.amount.map { "・\($0.formatted()) \(meal.unit ?? "")" } ?? ""
            return DailyTimelineItem(id: .meal(meal.persistentModelID), kind: .meal, eventDate: meal.recordedAt, title: "\(meal.kind)・\(meal.content)\(amount)", detail: meal.note)
        }
        let sleepItems = sleeps.map { sleep in
            let title: String
            if let end = sleep.endedAt {
                let duration = max(0, end.timeIntervalSince(sleep.startedAt))
                title = "睡眠・\(duration.formattedDuration)"
            } else {
                title = "睡眠中"
            }
            return DailyTimelineItem(id: .sleep(sleep.persistentModelID), kind: .sleep, eventDate: sleep.startedAt, title: title, detail: sleep.note)
        }
        let diaperItems = diapers.map {
            DailyTimelineItem(id: .diaper($0.persistentModelID), kind: .diaper, eventDate: $0.recordedAt, title: "排便・\($0.condition)", detail: $0.note)
        }
        return (mealItems + sleepItems + diaperItems)
            .filter { item in day.map { calendar.isDate(item.eventDate, inSameDayAs: $0) } ?? true }
            .sorted { $0.eventDate > $1.eventDate }
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours) 小時 \(remainder) 分" : "\(remainder) 分"
    }
}

enum BabyProfileValidationError: Error, Equatable {
    case emptyName
    case futureBirthday
}

enum BabyProfileValidator {
    static func validate(name: String, birthday: Date, now: Date = .now) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BabyProfileValidationError.emptyName
        }
        guard birthday <= now else { throw BabyProfileValidationError.futureBirthday }
    }
}

