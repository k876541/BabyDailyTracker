import Foundation

enum MedicationReminderCoordinatorError: Error, Equatable {
    case notificationsDenied
    case occurrenceInPast
    case rollbackFailed
}

@MainActor
protocol MedicationReminderCoordinating: AnyObject {
    func create(_ draft: MedicationReminderDraft) async throws
    func update(planID: UUID, draft: MedicationReminderDraft) async throws
    func complete(occurrenceID: UUID, at date: Date) async throws
    func snooze(occurrenceID: UUID, now: Date) async throws
    func end(planID: UUID, at date: Date) async throws
    func delete(planID: UUID) async throws
    func reconcile(now: Date) async throws
}

@MainActor
final class MedicationReminderCoordinator: MedicationReminderCoordinating {
    private let repository: MedicationReminderRepository
    private let scheduler: MedicationNotificationScheduling
    private let calendar: Calendar
    private let now: () -> Date

    init(
        repository: MedicationReminderRepository,
        scheduler: MedicationNotificationScheduling,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    func create(_ draft: MedicationReminderDraft) async throws {
        let expandedDates = try MedicationScheduleBuilder.occurrenceDates(for: draft, calendar: calendar)
        let currentDate = now()
        let dates = expandedDates.filter { $0 > currentDate }
        guard !dates.isEmpty else {
            throw MedicationReminderCoordinatorError.occurrenceInPast
        }
        try await ensureAuthorization()
        let plan = try repository.create(draft: draft, dates: dates)
        do {
            try await scheduleFixed(plan.occurrences)
        } catch {
            let ids = plan.occurrences.map(\.id)
            scheduler.cancel(occurrenceIDs: ids)
            try? repository.delete(planID: plan.id)
            throw error
        }
    }

    func update(planID: UUID, draft: MedicationReminderDraft) async throws {
        let expandedDates = try MedicationScheduleBuilder.occurrenceDates(for: draft, calendar: calendar)
        let currentDate = now()
        let newDates = expandedDates.filter { $0 > currentDate }
        guard !newDates.isEmpty else {
            throw MedicationReminderCoordinatorError.occurrenceInPast
        }
        try await ensureAuthorization()
        guard let current = try repository.activePlan(), current.id == planID else {
            throw MedicationReminderRepositoryError.planNotFound
        }
        let previousDraft = MedicationReminderDraft(
            startDate: current.startDate,
            durationDays: current.durationDays,
            times: current.times.map { MedicationReminderTime(hour: $0.hour, minute: $0.minute) },
            minimumIntervalMinutes: current.minimumIntervalMinutes,
            snoozeMinutes: current.snoozeMinutes
        )
        let previousDates = current.occurrences
            .filter { $0.status != .completed }
            .map(\.scheduledAt)
            .sorted()
        let previousIDs = current.occurrences.map(\.id)

        let updated = try repository.replace(planID: planID, draft: draft, dates: newDates)
        scheduler.cancel(occurrenceIDs: previousIDs)
        do {
            try await scheduleFixed(updated.occurrences)
        } catch {
            scheduler.cancel(occurrenceIDs: updated.occurrences.map(\.id))
            do {
                let restored = try repository.replace(
                    planID: planID,
                    draft: previousDraft,
                    dates: previousDates
                )
                try await scheduleFixed(restored.occurrences)
            } catch {
                throw MedicationReminderCoordinatorError.rollbackFailed
            }
            throw error
        }
    }

    func complete(occurrenceID: UUID, at date: Date) async throws {
        try repository.complete(occurrenceID: occurrenceID, at: date)
        scheduler.cancel(occurrenceIDs: [occurrenceID])
    }

    func snooze(occurrenceID: UUID, now: Date) async throws {
        guard let plan = try repository.activePlan(),
              let occurrence = plan.occurrences.first(where: { $0.id == occurrenceID }) else {
            throw MedicationReminderRepositoryError.occurrenceNotFound
        }
        guard occurrence.status != .completed else { return }
        guard let reminderDate = calendar.date(
            byAdding: .minute,
            value: plan.snoozeMinutes,
            to: now
        ) else {
            throw MedicationScheduleValidationError.invalidCalendarDate
        }
        try await scheduler.scheduleSnooze(occurrenceID: occurrenceID, at: reminderDate)
        do {
            try repository.snooze(occurrenceID: occurrenceID, until: reminderDate)
        } catch {
            scheduler.cancel(occurrenceIDs: [occurrenceID])
            throw error
        }
    }

    func end(planID: UUID, at date: Date) async throws {
        guard let plan = try repository.activePlan(), plan.id == planID else {
            throw MedicationReminderRepositoryError.planNotFound
        }
        let ids = unfinishedIDs(in: plan)
        try repository.end(planID: planID, at: date)
        scheduler.cancel(occurrenceIDs: ids)
    }

    func delete(planID: UUID) async throws {
        guard let plan = try repository.activePlan(), plan.id == planID else {
            throw MedicationReminderRepositoryError.planNotFound
        }
        let ids = unfinishedIDs(in: plan)
        try repository.delete(planID: planID)
        scheduler.cancel(occurrenceIDs: ids)
    }

    func reconcile(now: Date) async throws {
        let occurrences = try repository.futureOccurrences(from: now)
        scheduler.cancel(occurrenceIDs: occurrences.map(\.id))
        for occurrence in occurrences {
            if occurrence.status == .snoozed, let reminderDate = occurrence.nextReminderAt {
                try await scheduler.scheduleSnooze(occurrenceID: occurrence.id, at: reminderDate)
            } else {
                try await scheduler.scheduleFixed(occurrenceID: occurrence.id, at: occurrence.scheduledAt)
            }
        }
    }

    private func ensureAuthorization() async throws {
        switch await scheduler.authorizationStatus() {
        case .authorized:
            return
        case .denied:
            throw MedicationReminderCoordinatorError.notificationsDenied
        case .notDetermined:
            guard try await scheduler.requestAuthorization() else {
                throw MedicationReminderCoordinatorError.notificationsDenied
            }
        }
    }

    private func scheduleFixed(_ occurrences: [MedicationDoseOccurrence]) async throws {
        for occurrence in occurrences.sorted(by: { $0.scheduledAt < $1.scheduledAt }) {
            try await scheduler.scheduleFixed(occurrenceID: occurrence.id, at: occurrence.scheduledAt)
        }
    }

    private func unfinishedIDs(in plan: MedicationReminderPlan) -> [UUID] {
        plan.occurrences
            .filter { $0.status == .pending || $0.status == .snoozed }
            .map(\.id)
    }
}
