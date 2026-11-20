import Foundation
import Observation

@MainActor
@Observable
final class GrowthViewModel {
    private let repository: any GrowthRepository
    private let profileRepository: BabyProfileRepository
    var records: [GrowthRecord] = []
    var profile: BabyProfile?
    var errorMessage: String?
    var selectedMetric: GrowthMetric = .height

    init(repository: any GrowthRepository, profileRepository: BabyProfileRepository) {
        self.repository = repository
        self.profileRepository = profileRepository
    }

    func load() {
        do {
            records = try repository.fetch()
            profile = try profileRepository.fetchOrCreate()
        }
        catch { errorMessage = "無法讀取成長紀錄：\(error.localizedDescription)" }
    }

    func saveProfile(name: String, birthday: Date) {
        guard let profile else { return }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "寶寶" : name
        profile.birthday = birthday
        do { try profileRepository.save(profile) }
        catch { errorMessage = "無法儲存寶寶資料：\(error.localizedDescription)" }
    }

    func save(record: GrowthRecord, measuredAt: Date, height: Double?, weight: Double?) -> Bool {
        do {
            try GrowthInputValidator.validate(height: height, weight: weight)
            record.measuredAt = measuredAt
            record.heightCM = height
            record.weightKG = weight
            try repository.save(record)
            load()
            return true
        } catch GrowthValidationError.missingMeasurement {
            errorMessage = "請至少填寫身高或體重。"
        } catch GrowthValidationError.invalidHeight {
            errorMessage = "身高必須是大於 0 的數字。"
        } catch GrowthValidationError.invalidWeight {
            errorMessage = "體重必須是大於 0 的數字。"
        } catch {
            errorMessage = "無法儲存：\(error.localizedDescription)"
        }
        return false
    }

    func delete(_ record: GrowthRecord) {
        do { try repository.delete(record); load() }
        catch { errorMessage = "無法刪除：\(error.localizedDescription)" }
    }

    var samples: [GrowthSample] { records.map(\.sample) }
    func summary(for metric: GrowthMetric) -> GrowthSummary? {
        GrowthMetrics.summary(for: metric, samples: samples)
    }
    var trend: [GrowthPoint] { GrowthMetrics.trend(for: selectedMetric, samples: samples) }
}

