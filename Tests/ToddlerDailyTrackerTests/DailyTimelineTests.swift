import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("Daily timeline")
struct DailyTimelineTests {
    @Test("Records from all categories merge by event time newest first")
    func recordsMergeNewestFirst() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let meals = [MealRecord(recordedAt: base, kind: "奶", content: "配方奶", amount: 180, unit: "ml")]
        let sleeps = [SleepRecord(startedAt: base.addingTimeInterval(100), endedAt: base.addingTimeInterval(200))]
        let diapers = [DiaperRecord(recordedAt: base.addingTimeInterval(300), condition: "正常")]

        let items = DailyTimelineBuilder.build(meals: meals, sleeps: sleeps, diapers: diapers)

        #expect(items.map(\.kind) == [.diaper, .sleep, .meal])
        #expect(items.map(\.eventDate) == [base.addingTimeInterval(300), base.addingTimeInterval(100), base])
    }

    @Test("Timeline excludes records outside the requested day")
    func timelineFiltersByDay() {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let meals = [
            MealRecord(recordedAt: day, kind: "正餐", content: "粥"),
            MealRecord(recordedAt: tomorrow, kind: "正餐", content: "麵")
        ]

        let items = DailyTimelineBuilder.build(meals: meals, sleeps: [], diapers: [], day: day, calendar: calendar)

        #expect(items.count == 1)
        #expect(items.first?.title.contains("粥") == true)
    }

    @Test("Meal amount must be positive when supplied")
    func mealAmountMustBePositive() {
        #expect(throws: DailyRecordValidationError.invalidMealAmount) {
            try DailyRecordValidator.validateMealAmount(0)
        }
        #expect(throws: Never.self) {
            try DailyRecordValidator.validateMealAmount(180)
        }
    }

    @Test("Only one sleep may be in progress")
    func onlyOneSleepMayBeActive() {
        let active = SleepRecord(startedAt: .now, endedAt: nil)
        #expect(throws: DailyRecordValidationError.sleepAlreadyInProgress) {
            try DailyRecordValidator.validateCanStartSleep(records: [active])
        }
    }

    @Test("Completing sleep requires an end after its start")
    func completingSleepRequiresValidEnd() {
        let start = Date(timeIntervalSince1970: 200)
        #expect(throws: DailyRecordValidationError.invalidSleepRange) {
            try DailyRecordValidator.validateSleep(start: start, end: Date(timeIntervalSince1970: 100))
        }
    }

    @Test("Timeline identity remains stable when records share a timestamp")
    func timelineIdentityUsesSourceRecord() {
        let timestamp = Date(timeIntervalSince1970: 200)
        let first = MealRecord(recordedAt: timestamp, kind: "奶", content: "母奶")
        let second = MealRecord(recordedAt: timestamp, kind: "奶", content: "配方奶")

        let firstBuild = DailyTimelineBuilder.build(meals: [first, second], sleeps: [], diapers: [])
        let secondBuild = DailyTimelineBuilder.build(meals: [first, second], sleeps: [], diapers: [])

        #expect(Set(firstBuild.map(\.id)).count == 2)
        #expect(Set(firstBuild.map(\.id)) == Set(secondBuild.map(\.id)))
    }
}
