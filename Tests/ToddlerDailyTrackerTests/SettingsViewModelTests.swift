import Foundation
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Settings view model")
struct SettingsViewModelTests {
    @Test("First confirmation does not reset data")
    func firstConfirmationDoesNotResetData() {
        let repository = RecordingResetRepository()
        let viewModel = SettingsViewModel(repository: repository, scheduler: RecordingResetScheduler())

        viewModel.requestReset()
        viewModel.confirmFirstReset()

        #expect(viewModel.confirmationStage == .permanent)
        #expect(repository.resetCount == 0)
    }

    @Test("Permanent confirmation resets once and cancels returned notifications")
    func permanentConfirmationResetsOnceAndCancelsNotifications() async {
        let occurrenceID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let repository = RecordingResetRepository(ids: [occurrenceID])
        let scheduler = RecordingResetScheduler()
        let viewModel = SettingsViewModel(repository: repository, scheduler: scheduler)
        viewModel.requestReset()
        viewModel.confirmFirstReset()

        let firstResult = await viewModel.confirmPermanentReset()
        let secondResult = await viewModel.confirmPermanentReset()

        #expect(firstResult)
        #expect(!secondResult)
        #expect(repository.resetCount == 1)
        #expect(scheduler.cancelledIDs == [occurrenceID])
    }

    @Test("Reset failure keeps settings active and does not cancel notifications")
    func resetFailureKeepsSettingsActive() async {
        let repository = RecordingResetRepository(error: ResetTestError.failed)
        let scheduler = RecordingResetScheduler()
        let viewModel = SettingsViewModel(repository: repository, scheduler: scheduler)
        viewModel.requestReset()
        viewModel.confirmFirstReset()

        let result = await viewModel.confirmPermanentReset()

        #expect(!result)
        #expect(viewModel.confirmationStage == .none)
        #expect(viewModel.errorMessage != nil)
        #expect(scheduler.cancelledIDs.isEmpty)
    }
}

@MainActor
private final class RecordingResetRepository: AppDataResetRepository {
    let ids: [UUID]
    let error: Error?
    var resetCount = 0

    init(ids: [UUID] = [], error: Error? = nil) {
        self.ids = ids
        self.error = error
    }

    func reset() throws -> [UUID] {
        resetCount += 1
        if let error { throw error }
        return ids
    }
}

@MainActor
private final class RecordingResetScheduler: MedicationNotificationScheduling {
    var cancelledIDs: [UUID] = []
    func authorizationStatus() async -> MedicationNotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func registerActions() {}
    func scheduleFixed(occurrenceID: UUID, at date: Date) async throws {}
    func scheduleSnooze(occurrenceID: UUID, at date: Date) async throws {}
    func cancel(occurrenceIDs: [UUID]) { cancelledIDs.append(contentsOf: occurrenceIDs) }
}

private enum ResetTestError: Error {
    case failed
}
