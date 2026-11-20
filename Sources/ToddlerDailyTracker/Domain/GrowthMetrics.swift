import Foundation

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
}

enum DailyRecordValidator {
    static func validateSleep(start: Date, end: Date) throws {
        guard end >= start else { throw DailyRecordValidationError.invalidSleepRange }
    }
}

