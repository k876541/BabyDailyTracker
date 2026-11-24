import Foundation
import Observation

enum SettingsConfirmationStage: Equatable {
    case none
    case first
    case permanent
}

@MainActor
@Observable
final class SettingsViewModel {
    private let repository: AppDataResetRepository
    private let scheduler: MedicationNotificationScheduling

    var confirmationStage: SettingsConfirmationStage = .none
    var errorMessage: String?
    var isResetting = false

    init(
        repository: AppDataResetRepository,
        scheduler: MedicationNotificationScheduling
    ) {
        self.repository = repository
        self.scheduler = scheduler
    }

    func requestReset() {
        guard !isResetting else { return }
        confirmationStage = .first
    }

    func confirmFirstReset() {
        guard confirmationStage == .first, !isResetting else { return }
        confirmationStage = .permanent
    }

    func cancelReset() {
        guard !isResetting else { return }
        confirmationStage = .none
    }

    func confirmPermanentReset() async -> Bool {
        guard confirmationStage == .permanent, !isResetting else { return false }
        confirmationStage = .none
        isResetting = true
        defer { isResetting = false }

        do {
            let occurrenceIDs = try repository.reset()
            scheduler.cancel(occurrenceIDs: occurrenceIDs)
            return true
        } catch {
            errorMessage = "無法移除寶寶資料：\(error.localizedDescription)"
            return false
        }
    }
}
