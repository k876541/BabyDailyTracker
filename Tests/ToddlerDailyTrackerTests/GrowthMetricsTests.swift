import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("Growth record validation and metrics")
struct GrowthMetricsTests {
    @Test("A height-only measurement is valid")
    func heightOnlyIsValid() throws {
        #expect(throws: Never.self) {
            try GrowthInputValidator.validate(height: 82.5, weight: nil)
        }
    }

    @Test("A weight-only measurement is valid")
    func weightOnlyIsValid() throws {
        #expect(throws: Never.self) {
            try GrowthInputValidator.validate(height: nil, weight: 11.2)
        }
    }

    @Test("An empty measurement is rejected")
    func emptyIsRejected() {
        #expect(throws: GrowthValidationError.missingMeasurement) {
            try GrowthInputValidator.validate(height: nil, weight: nil)
        }
    }

    @Test(arguments: [0.0, -1.0, .infinity, .nan])
    func invalidHeightIsRejected(_ value: Double) {
        #expect(throws: GrowthValidationError.invalidHeight) {
            try GrowthInputValidator.validate(height: value, weight: nil)
        }
    }

    @Test("Non-numeric measurement text is rejected instead of treated as empty")
    func nonNumericTextIsRejected() {
        #expect(throws: GrowthValidationError.invalidHeight) {
            try GrowthInputParser.parse(heightText: "abc", weightText: "10.5")
        }
    }

    @Test("Whitespace-only measurement text remains empty")
    func whitespaceIsEmpty() throws {
        let result = try GrowthInputParser.parse(heightText: "  ", weightText: "10.5")
        #expect(result.height == nil)
        #expect(result.weight == 10.5)
    }

    @Test("Height delta skips records without height and uses measurement date")
    func heightDeltaUsesPreviousValidHeight() {
        let day: TimeInterval = 86_400
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = [
            GrowthSample(measuredAt: base, heightCM: 80, weightKG: 10),
            GrowthSample(measuredAt: base.addingTimeInterval(day), heightCM: nil, weightKG: 10.5),
            GrowthSample(measuredAt: base.addingTimeInterval(day * 2), heightCM: 83, weightKG: nil)
        ]

        let summary = GrowthMetrics.summary(for: .height, samples: samples)

        #expect(summary?.latest == 83)
        #expect(summary?.change == 3)
    }

    @Test("Backfilled values are sorted by actual measurement date")
    func trendSortsByMeasurementDate() {
        let newest = Date(timeIntervalSince1970: 300)
        let oldest = Date(timeIntervalSince1970: 100)
        let middle = Date(timeIntervalSince1970: 200)
        let samples = [
            GrowthSample(measuredAt: newest, heightCM: 90, weightKG: nil),
            GrowthSample(measuredAt: oldest, heightCM: 80, weightKG: nil),
            GrowthSample(measuredAt: middle, heightCM: 85, weightKG: nil)
        ]

        #expect(GrowthMetrics.trend(for: .height, samples: samples).map(\.value) == [80, 85, 90])
    }
}

