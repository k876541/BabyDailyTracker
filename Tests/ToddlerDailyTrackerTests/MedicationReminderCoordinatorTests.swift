import Foundation
import SwiftData
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Medication reminder coordinator")
struct MedicationReminderCoordinatorTests {
    @Test("Create requests permission when status is not determined")
    func createRequestsPermissionWhenUndetermined() async throws {
        let fixture = try makeFixture(authorization: .notDetermined)

        try await fixture.coordinator.create(draft())

        #expect(fixture.scheduler.authorizationRequestCount == 1)
        #expect(try fixture.repository.activePlan() != nil)
    }

    @Test("Denied permission does not create a course")
    func deniedPermissionDoesNotCreateCourse() async throws {
        let fixture = try makeFixture(authorization: .denied)

        await expectCoordinatorError(.notificationsDenied) {
            try await fixture.coordinator.create(draft())
        }

        #expect(try fixture.repository.activePlan() == nil)
        #expect(fixture.scheduler.fixed.isEmpty)
    }

    @Test("Rejecting the first permission prompt does not create a course")
    func rejectedPermissionRequestDoesNotCreateCourse() async throws {
        let fixture = try makeFixture(authorization: .notDetermined)
        fixture.scheduler.authorizationResult = false

        await expectCoordinatorError(.notificationsDenied) {
            try await fixture.coordinator.create(draft())
        }

        #expect(try fixture.repository.activePlan() == nil)
        #expect(fixture.scheduler.fixed.isEmpty)
    }

    @Test("Past occurrences are rejected before persistence")
    func pastOccurrencesAreRejectedBeforePersistence() async throws {
        let fixture = try makeFixture(now: { date(10) })

        await expectCoordinatorError(.occurrenceInPast) {
            try await fixture.coordinator.create(draft(times: [time(9)]))
        }

        #expect(try fixture.repository.activePlan() == nil)
    }

    @Test("Create skips elapsed times today and keeps later days")
    func createSkipsElapsedTimesTodayAndKeepsLaterDays() async throws {
        let fixture = try makeFixture(now: { date(12, minute: 17) })

        try await fixture.coordinator.create(draft(durationDays: 2))

        let plan = try #require(try fixture.repository.activePlan())
        #expect(plan.occurrences.map(\.scheduledAt).sorted() == [
            date(13),
            date(17),
            date(9, dayOffset: 1),
            date(13, dayOffset: 1),
            date(17, dayOffset: 1)
        ])
        #expect(fixture.scheduler.fixed.map(\.date) == plan.occurrences.map(\.scheduledAt).sorted())
    }

    @Test("Create schedules every occurrence")
    func createSchedulesAllOccurrences() async throws {
        let fixture = try makeFixture()

        try await fixture.coordinator.create(draft())

        #expect(fixture.scheduler.fixed.map(\.date) == [date(9), date(13), date(17)])
    }

    @Test("Create rolls back after a scheduling failure")
    func createRollsBackAfterSchedulingFailure() async throws {
        let fixture = try makeFixture()
        fixture.scheduler.failAtScheduleCall = 2

        await expectAnyError {
            try await fixture.coordinator.create(draft())
        }

        #expect(try fixture.repository.activePlan() == nil)
        #expect(fixture.scheduler.cancelledIDs.count == 3)
    }

    @Test("Update replaces occurrences and notification requests")
    func updateReplacesOccurrencesAndRequests() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        let oldIDs = Set(plan.occurrences.map(\.id))
        fixture.scheduler.resetCalls()
        let replacement = draft(
            durationDays: 2,
            times: [MedicationReminderTime(hour: 8, minute: 0), MedicationReminderTime(hour: 20, minute: 0)],
            minimumIntervalMinutes: 300
        )

        try await fixture.coordinator.update(planID: plan.id, draft: replacement)

        let updated = try #require(try fixture.repository.activePlan())
        #expect(updated.occurrences.count == 4)
        #expect(Set(fixture.scheduler.cancelledIDs) == oldIDs)
        #expect(fixture.scheduler.fixed.map(\.date) == [
            date(8), date(20), date(8, dayOffset: 1), date(20, dayOffset: 1)
        ])
    }

    @Test("Update failure restores the previous schedule")
    func updateFailureRestoresPreviousSchedule() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        fixture.scheduler.resetCalls()
        fixture.scheduler.failAtScheduleCall = 2

        await expectAnyError {
            try await fixture.coordinator.update(
                planID: plan.id,
                draft: draft(times: [MedicationReminderTime(hour: 8, minute: 0), MedicationReminderTime(hour: 20, minute: 0)])
            )
        }

        let restored = try #require(try fixture.repository.activePlan())
        #expect(restored.times.map(\.hour).sorted() == [9, 13, 17])
        #expect(restored.occurrences.map(\.scheduledAt).sorted() == [date(9), date(13), date(17)])
        #expect(Array(fixture.scheduler.fixed.suffix(3)).map(\.date) == [date(9), date(13), date(17)])
    }

    @Test("Complete action is idempotent")
    func completeActionIsIdempotent() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let occurrence = try #require(try fixture.repository.activePlan()?.occurrences.first)
        let first = date(9, minute: 20)

        try await fixture.coordinator.complete(occurrenceID: occurrence.id, at: first)
        try await fixture.coordinator.complete(occurrenceID: occurrence.id, at: date(9, minute: 40))

        #expect(occurrence.completedAt == first)
        #expect(occurrence.status == .completed)
    }

    @Test("Repeated snooze replaces the previous request")
    func snoozeReplacesPreviousRequest() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft(snoozeMinutes: 5))
        let occurrence = try #require(try fixture.repository.activePlan()?.occurrences.first)

        try await fixture.coordinator.snooze(occurrenceID: occurrence.id, now: date(9))
        try await fixture.coordinator.snooze(occurrenceID: occurrence.id, now: date(9, minute: 5))

        #expect(fixture.scheduler.snoozes.map(\.date) == [date(9, minute: 5), date(9, minute: 10)])
        #expect(occurrence.nextReminderAt == date(9, minute: 10))
        #expect(occurrence.snoozeCount == 2)
    }

    @Test("Late completion does not move the next occurrence")
    func lateCompletionDoesNotMoveNextOccurrence() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        let first = try #require(plan.occurrences.first { $0.scheduledAt == date(9) })

        try await fixture.coordinator.complete(occurrenceID: first.id, at: date(9, minute: 30))

        #expect(plan.occurrences.first { $0.scheduledAt == date(13) }?.scheduledAt == date(13))
    }

    @Test("End cancels all future requests")
    func endCancelsFutureRequests() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        let ids = Set(plan.occurrences.map(\.id))
        fixture.scheduler.resetCalls()

        try await fixture.coordinator.end(planID: plan.id, at: date(8))

        #expect(Set(fixture.scheduler.cancelledIDs) == ids)
        #expect(!plan.isActive)
    }

    @Test("Delete cancels all future requests")
    func deleteCancelsFutureRequests() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        let ids = Set(plan.occurrences.map(\.id))
        fixture.scheduler.resetCalls()

        try await fixture.coordinator.delete(planID: plan.id)

        #expect(Set(fixture.scheduler.cancelledIDs) == ids)
        #expect(try fixture.repository.activePlan() == nil)
    }

    @Test("Reconcile replaces future requests")
    func reconcileReplacesFutureRequests() async throws {
        let fixture = try makeFixture()
        try await fixture.coordinator.create(draft())
        let plan = try #require(try fixture.repository.activePlan())
        let first = try #require(plan.occurrences.first { $0.scheduledAt == date(9) })
        try fixture.repository.snooze(occurrenceID: first.id, until: date(9, minute: 5))
        fixture.scheduler.resetCalls()

        try await fixture.coordinator.reconcile(now: date(8))

        #expect(Set(fixture.scheduler.cancelledIDs) == Set(plan.occurrences.map(\.id)))
        #expect(fixture.scheduler.snoozes.map(\.id) == [first.id])
        #expect(fixture.scheduler.snoozes.map(\.date) == [date(9, minute: 5)])
        #expect(fixture.scheduler.fixed.map(\.date) == [date(13), date(17)])
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
    }

    private func draft(
        durationDays: Int = 1,
        times: [MedicationReminderTime] = [
            MedicationReminderTime(hour: 9, minute: 0),
            MedicationReminderTime(hour: 13, minute: 0),
            MedicationReminderTime(hour: 17, minute: 0)
        ],
        minimumIntervalMinutes: Int = 240,
        snoozeMinutes: Int = 5
    ) -> MedicationReminderDraft {
        MedicationReminderDraft(
            startDate: day,
            durationDays: durationDays,
            times: times,
            minimumIntervalMinutes: minimumIntervalMinutes,
            snoozeMinutes: snoozeMinutes
        )
    }

    private func time(_ hour: Int) -> MedicationReminderTime {
        MedicationReminderTime(hour: hour, minute: 0)
    }

    private func date(_ hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: dayOffset, to: day)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func makeFixture(
        authorization: MedicationNotificationAuthorization = .authorized,
        now: @escaping () -> Date = { Date.distantPast }
    ) throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MedicationReminderPlan.self,
            MedicationReminderTimeModel.self,
            MedicationDoseOccurrence.self,
            configurations: configuration
        )
        let repository = SwiftDataMedicationReminderRepository(context: container.mainContext)
        let scheduler = RecordingMedicationScheduler(authorization: authorization)
        return Fixture(
            container: container,
            repository: repository,
            scheduler: scheduler,
            coordinator: MedicationReminderCoordinator(
                repository: repository,
                scheduler: scheduler,
                calendar: calendar,
                now: now
            )
        )
    }

    private func expectCoordinatorError(
        _ expected: MedicationReminderCoordinatorError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected coordinator error")
        } catch {
            #expect(error as? MedicationReminderCoordinatorError == expected)
        }
    }

    private func expectAnyError(operation: () async throws -> Void) async {
        do {
            try await operation()
            Issue.record("Expected an error")
        } catch {}
    }

    private struct Fixture {
        let container: ModelContainer
        let repository: SwiftDataMedicationReminderRepository
        let scheduler: RecordingMedicationScheduler
        let coordinator: MedicationReminderCoordinator
    }
}

@MainActor
private final class RecordingMedicationScheduler: MedicationNotificationScheduling {
    struct Call: Equatable {
        let id: UUID
        let date: Date
    }

    var authorization: MedicationNotificationAuthorization
    var authorizationResult = true
    var authorizationRequestCount = 0
    var fixed: [Call] = []
    var snoozes: [Call] = []
    var cancelledIDs: [UUID] = []
    var scheduleCallCount = 0
    var failAtScheduleCall: Int?

    init(authorization: MedicationNotificationAuthorization) {
        self.authorization = authorization
    }

    func authorizationStatus() async -> MedicationNotificationAuthorization { authorization }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationResult
    }

    func registerActions() {}

    func scheduleFixed(occurrenceID: UUID, at date: Date) async throws {
        try recordScheduleCall()
        fixed.append(Call(id: occurrenceID, date: date))
    }

    func scheduleSnooze(occurrenceID: UUID, at date: Date) async throws {
        try recordScheduleCall()
        snoozes.append(Call(id: occurrenceID, date: date))
    }

    func cancel(occurrenceIDs: [UUID]) {
        cancelledIDs.append(contentsOf: occurrenceIDs)
    }

    func resetCalls() {
        fixed = []
        snoozes = []
        cancelledIDs = []
        scheduleCallCount = 0
        failAtScheduleCall = nil
    }

    private func recordScheduleCall() throws {
        scheduleCallCount += 1
        if scheduleCallCount == failAtScheduleCall {
            throw RecordingSchedulerError.failed
        }
    }
}

private enum RecordingSchedulerError: Error {
    case failed
}
