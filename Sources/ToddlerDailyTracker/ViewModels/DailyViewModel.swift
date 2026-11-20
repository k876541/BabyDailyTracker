import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DailyViewModel {
    private let repository: DailyRecordRepository
    var meals: [MealRecord] = []
    var sleeps: [SleepRecord] = []
    var diapers: [DiaperRecord] = []
    var errorMessage: String?

    init(repository: DailyRecordRepository) { self.repository = repository }

    func load() {
        do {
            meals = try repository.meals()
            sleeps = try repository.sleeps()
            diapers = try repository.diapers()
        } catch { errorMessage = "無法讀取紀錄：\(error.localizedDescription)" }
    }

    func saveMeal(_ record: MealRecord) -> Bool {
        do { try DailyRecordValidator.validateMealAmount(record.amount) }
        catch { errorMessage = "份量必須是大於 0 的數字。"; return false }
        return save(record)
    }

    var timeline: [DailyTimelineItem] {
        DailyTimelineBuilder.build(meals: meals, sleeps: sleeps, diapers: diapers, day: .now)
    }

    var activeSleep: SleepRecord? { sleeps.first(where: { $0.endedAt == nil }) }

    func startSleep(at date: Date = .now) -> Bool {
        do {
            try DailyRecordValidator.validateCanStartSleep(records: sleeps)
            return save(SleepRecord(startedAt: date))
        } catch {
            errorMessage = "已有一筆進行中的睡眠。"
            return false
        }
    }

    func finishActiveSleep(at date: Date = .now) -> Bool {
        guard let sleep = activeSleep else {
            errorMessage = "目前沒有進行中的睡眠。"
            return false
        }
        do {
            try DailyRecordValidator.validateSleep(start: sleep.startedAt, end: date)
            sleep.endedAt = date
            return save(sleep)
        } catch {
            errorMessage = "結束時間不可早於開始時間。"
            return false
        }
    }

    func saveSleep(_ record: SleepRecord) -> Bool {
        guard let endedAt = record.endedAt else { return save(record) }
        do { try DailyRecordValidator.validateSleep(start: record.startedAt, end: endedAt) }
        catch { errorMessage = "睡眠結束時間不可早於開始時間。"; return false }
        return save(record)
    }

    func saveDiaper(_ record: DiaperRecord) -> Bool { save(record) }

    private func save<T: PersistentModel>(_ record: T) -> Bool {
        do { try repository.save(record); load(); return true }
        catch { errorMessage = "無法儲存：\(error.localizedDescription)"; return false }
    }

    func delete<T: PersistentModel>(_ record: T) {
        do { try repository.delete(record); load() }
        catch { errorMessage = "無法刪除：\(error.localizedDescription)" }
    }
}
