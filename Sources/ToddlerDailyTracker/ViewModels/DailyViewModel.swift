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

    func saveMeal(_ record: MealRecord) -> Bool { save(record) }

    func saveSleep(_ record: SleepRecord) -> Bool {
        do { try DailyRecordValidator.validateSleep(start: record.startedAt, end: record.endedAt) }
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
