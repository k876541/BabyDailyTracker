import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HistoryViewModel {
    private let repository: DailyRecordRepository
    private let now: () -> Date
    private let calendar: Calendar

    private(set) var selectedDate: Date
    private(set) var meals: [MealRecord] = []
    private(set) var sleeps: [SleepRecord] = []
    private(set) var diapers: [DiaperRecord] = []
    var errorMessage: String?

    init(
        repository: DailyRecordRepository,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        selectedDate = calendar.startOfDay(for: now())
    }

    var timeline: [DailyTimelineItem] {
        HistoryCalculator.timeline(
            meals: meals,
            sleeps: sleeps,
            diapers: diapers,
            day: selectedDate,
            calendar: calendar
        )
    }

    var dailySummary: DailyHistorySummary {
        HistoryCalculator.dailySummary(
            meals: meals,
            sleeps: sleeps,
            diapers: diapers,
            day: selectedDate,
            now: now(),
            calendar: calendar
        )
    }

    var weeklySummary: WeeklyHistorySummary {
        HistoryCalculator.weeklySummary(
            meals: meals,
            sleeps: sleeps,
            diapers: diapers,
            endingOn: selectedDate,
            now: now(),
            calendar: calendar
        )
    }

    var canSelectNextDay: Bool {
        !calendar.isDate(selectedDate, inSameDayAs: now())
    }

    func select(_ date: Date) {
        let today = calendar.startOfDay(for: now())
        selectedDate = min(calendar.startOfDay(for: date), today)
    }

    func selectPreviousDay() {
        guard let value = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        select(value)
    }

    func selectNextDay() {
        guard let value = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        select(value)
    }

    func load() {
        do {
            meals = try repository.meals()
            sleeps = try repository.sleeps()
            diapers = try repository.diapers()
        } catch {
            errorMessage = "無法讀取紀錄：\(error.localizedDescription)"
        }
    }

    func saveMeal(_ record: MealRecord) -> Bool {
        do { try DailyRecordValidator.validateMealAmount(record.amount) }
        catch {
            errorMessage = "份量必須是大於 0 的數字。"
            return false
        }
        return save(record)
    }

    func saveSleep(_ record: SleepRecord) -> Bool {
        if let endedAt = record.endedAt {
            do { try DailyRecordValidator.validateSleep(start: record.startedAt, end: endedAt) }
            catch {
                errorMessage = "睡眠結束時間不可早於開始時間。"
                return false
            }
        }
        return save(record)
    }

    func saveDiaper(_ record: DiaperRecord) -> Bool {
        save(record)
    }

    func delete<T: PersistentModel>(_ record: T) {
        do {
            try repository.delete(record)
            load()
        } catch {
            errorMessage = "無法刪除：\(error.localizedDescription)"
        }
    }

    private func save<T: PersistentModel>(_ record: T) -> Bool {
        do {
            try repository.save(record)
            load()
            return true
        } catch {
            errorMessage = "無法儲存：\(error.localizedDescription)"
            return false
        }
    }
}
