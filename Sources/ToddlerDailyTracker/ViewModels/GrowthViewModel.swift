import Foundation
import Observation

@MainActor
@Observable
final class GrowthViewModel {
    private let repository: any GrowthRepository
    private let profileRepository: any BabyProfileRepository
    var records: [GrowthRecord] = []
    var profile: BabyProfile?
    var errorMessage: String?
    var selectedMetric: GrowthMetric = .height

    init(repository: any GrowthRepository, profileRepository: any BabyProfileRepository) {
        self.repository = repository
        self.profileRepository = profileRepository
    }

    func load() {
        do {
            records = try repository.fetch()
            profile = try profileRepository.fetchProfile()
        }
        catch { errorMessage = "無法讀取成長紀錄：\(error.localizedDescription)" }
    }

    func saveProfile(name: String, birthday: Date) {
        guard let profile else { return }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "寶寶" : name
        profile.birthday = birthday
        do { try BabyProfileValidator.validate(name: profile.name, birthday: birthday); try profileRepository.updateProfile(profile) }
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

enum AppLaunchState: Equatable {
    case loading
    case needsBabyProfile
    case ready
}

@MainActor
@Observable
final class AppLaunchViewModel {
    private let repository: any BabyProfileRepository
    private let defaults: UserDefaults
    var state: AppLaunchState = .loading
    var errorMessage: String?

    init(repository: any BabyProfileRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    func load() {
        do { state = try repository.fetchProfile() == nil ? .needsBabyProfile : .ready }
        catch { errorMessage = "無法讀取寶寶資料：\(error.localizedDescription)"; state = .needsBabyProfile }
    }

    func save(name: String, birthday: Date) -> Bool {
        do {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try BabyProfileValidator.validate(name: normalizedName, birthday: birthday)
            _ = try repository.createProfile(name: normalizedName, birthday: birthday)
            state = .ready
            return true
        } catch BabyProfileValidationError.emptyName {
            errorMessage = "請輸入寶寶姓名。"
        } catch BabyProfileValidationError.futureBirthday {
            errorMessage = "生日不可晚於今天。"
        } catch {
            errorMessage = "無法儲存寶寶資料：\(error.localizedDescription)"
        }
        return false
    }

    func showOnboarding() {
        MedicationReminderNavigation.selectToday(in: defaults)
        state = .needsBabyProfile
    }
}

