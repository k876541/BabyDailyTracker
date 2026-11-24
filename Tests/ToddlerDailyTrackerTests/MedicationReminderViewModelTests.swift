import Foundation
import SwiftData
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Medication reminder view model")
struct MedicationReminderViewModelTests {
    @Test("No active plan shows the empty state")
    func emptyStateWhenNoPlan() throws {
        let fixture = try makeFixture()

        fixture.viewModel.load()

        #expect(fixture.viewModel.activePlan == nil)
        #expect(fixture.viewModel.todayOccurrences.isEmpty)
    }

    @Test("Load shows today's chronological occurrences")
    func loadShowsTodayOccurrences() throws {
        let fixture = try makeFixture()
        _ = try fixture.repository.create(draft: draft(), dates: [date(17), date(9), date(13)])

        fixture.viewModel.load()

        #expect(fixture.viewModel.todayOccurrences.map(\.scheduledAt) == [date(9), date(13), date(17)])
    }

    @Test("Maximum days reflects the forty-eight occurrence limit")
    func maximumDaysReflectsFortyEightOccurrenceLimit() throws {
        let fixture = try makeFixture()
        fixture.viewModel.draft.times = [time(9), time(13), time(17)]
        #expect(fixture.viewModel.maximumDurationDays == 16)

        fixture.viewModel.draft.times = [time(9)]
        #expect(fixture.viewModel.maximumDurationDays == 48)
    }

    @Test("Save shows an interval validation message")
    func saveShowsIntervalValidationMessage() async throws {
        let fixture = try makeFixture()
        fixture.viewModel.draft.times = [time(9), time(12)]

        await fixture.viewModel.save()

        #expect(fixture.coordinator.createCount == 0)
        #expect(fixture.viewModel.errorMessage == "提醒時間至少需間隔 4 小時。")
    }

    @Test("Save prevents reentry while the first save is suspended")
    func savePreventsReentry() async throws {
        let gate = SuspensionGate()
        let fixture = try makeFixture(gate: gate)

        let firstSave = Task { await fixture.viewModel.save() }
        await gate.waitUntilEntered()
        await fixture.viewModel.save()

        #expect(fixture.coordinator.createCount == 1)
        #expect(fixture.viewModel.isSaving)

        gate.release()
        await firstSave.value
        #expect(!fixture.viewModel.isSaving)
    }

    @Test("Late completion shows a gap warning without moving the next time")
    func lateCompletionProducesGapWarningWithoutChangingSchedule() throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9), date(13), date(17)])
        let afternoon = try #require(plan.occurrences.first { $0.scheduledAt == date(13) })
        try fixture.repository.complete(occurrenceID: afternoon.id, at: date(13, minute: 30))

        fixture.viewModel.load()

        #expect(fixture.viewModel.intervalWarning == "本次完成時間距離 17:00 的提醒少於 4 小時。")
        #expect(plan.occurrences.first { $0.scheduledAt == date(17) }?.scheduledAt == date(17))
    }

    @Test("Ending reloads to the empty state")
    func endReloadsState() async throws {
        let fixture = try makeFixture()
        let plan = try fixture.repository.create(draft: draft(), dates: [date(9), date(13), date(17)])
        fixture.viewModel.load()

        await fixture.viewModel.end()

        #expect(fixture.coordinator.endedPlanIDs == [plan.id])
        #expect(fixture.viewModel.activePlan == nil)
    }

    @Test("Repository failures become a user-visible message")
    func repositoryFailureBecomesUserMessage() {
        let repository = FailingMedicationReminderRepository()
        let viewModel = MedicationReminderViewModel(
            repository: repository,
            coordinator: RecordingMedicationCoordinator(),
            now: { day },
            calendar: calendar
        )

        viewModel.load()

        #expect(viewModel.errorMessage == "無法讀取餵藥提醒，請稍後再試。")
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
    }

    private func draft() -> MedicationReminderDraft {
        MedicationReminderDraft(
            startDate: day,
            durationDays: 1,
            times: [time(9), time(13), time(17)],
            minimumIntervalMinutes: 240,
            snoozeMinutes: 5
        )
    }

    private func time(_ hour: Int) -> MedicationReminderTime {
        MedicationReminderTime(hour: hour, minute: 0)
    }

    private func date(_ hour: Int, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func makeFixture(gate: SuspensionGate? = nil) throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MedicationReminderPlan.self,
            MedicationReminderTimeModel.self,
            MedicationDoseOccurrence.self,
            configurations: configuration
        )
        let repository = SwiftDataMedicationReminderRepository(context: container.mainContext)
        let coordinator = RecordingMedicationCoordinator(repository: repository, gate: gate)
        return Fixture(
            container: container,
            repository: repository,
            coordinator: coordinator,
            viewModel: MedicationReminderViewModel(
                repository: repository,
                coordinator: coordinator,
                now: { day },
                calendar: calendar
            )
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let repository: SwiftDataMedicationReminderRepository
        let coordinator: RecordingMedicationCoordinator
        let viewModel: MedicationReminderViewModel
    }
}

@MainActor
private final class RecordingMedicationCoordinator: MedicationReminderCoordinating {
    private let repository: MedicationReminderRepository?
    private let gate: SuspensionGate?
    var createCount = 0
    var endedPlanIDs: [UUID] = []

    init(repository: MedicationReminderRepository? = nil, gate: SuspensionGate? = nil) {
        self.repository = repository
        self.gate = gate
    }

    func create(_ draft: MedicationReminderDraft) async throws {
        createCount += 1
        if let gate { await gate.suspend() }
        guard let repository else { return }
        let dates = try MedicationScheduleBuilder.occurrenceDates(for: draft, calendar: .current)
        _ = try repository.create(draft: draft, dates: dates)
    }

    func update(planID: UUID, draft: MedicationReminderDraft) async throws {}
    func complete(occurrenceID: UUID, at date: Date) async throws {}
    func snooze(occurrenceID: UUID, now: Date) async throws {}

    func end(planID: UUID, at date: Date) async throws {
        endedPlanIDs.append(planID)
        try repository?.end(planID: planID, at: date)
    }

    func delete(planID: UUID) async throws {
        try repository?.delete(planID: planID)
    }

    func reconcile(now: Date) async throws {}
}

@MainActor
private final class SuspensionGate {
    private var entered = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor
private final class FailingMedicationReminderRepository: MedicationReminderRepository {
    func activePlan() throws -> MedicationReminderPlan? { throw TestRepositoryError.failed }
    func create(draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan { throw TestRepositoryError.failed }
    func replace(planID: UUID, draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan { throw TestRepositoryError.failed }
    func occurrences(on date: Date, calendar: Calendar) throws -> [MedicationDoseOccurrence] { throw TestRepositoryError.failed }
    func futureOccurrences(from date: Date) throws -> [MedicationDoseOccurrence] { throw TestRepositoryError.failed }
    func complete(occurrenceID: UUID, at date: Date) throws { throw TestRepositoryError.failed }
    func snooze(occurrenceID: UUID, until date: Date) throws { throw TestRepositoryError.failed }
    func end(planID: UUID, at date: Date) throws { throw TestRepositoryError.failed }
    func delete(planID: UUID) throws { throw TestRepositoryError.failed }
}

private enum TestRepositoryError: Error {
    case failed
}
