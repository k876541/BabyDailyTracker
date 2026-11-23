import Foundation
import SwiftData

enum MedicationReminderRepositoryError: Error, Equatable {
    case activePlanAlreadyExists
    case planNotFound
    case occurrenceNotFound
}

@MainActor
protocol MedicationReminderRepository: AnyObject {
    func activePlan() throws -> MedicationReminderPlan?
    func create(draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan
    func replace(planID: UUID, draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan
    func occurrences(on date: Date, calendar: Calendar) throws -> [MedicationDoseOccurrence]
    func futureOccurrences(from date: Date) throws -> [MedicationDoseOccurrence]
    func complete(occurrenceID: UUID, at date: Date) throws
    func snooze(occurrenceID: UUID, until date: Date) throws
    func end(planID: UUID, at date: Date) throws
    func delete(planID: UUID) throws
}

@MainActor
final class SwiftDataMedicationReminderRepository: MedicationReminderRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func activePlan() throws -> MedicationReminderPlan? {
        try allPlans().first(where: \.isActive)
    }

    func create(draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan {
        guard try activePlan() == nil else {
            throw MedicationReminderRepositoryError.activePlanAlreadyExists
        }
        let plan = makePlan(draft: draft, dates: dates)
        context.insert(plan)
        try context.save()
        return plan
    }

    func replace(
        planID: UUID,
        draft: MedicationReminderDraft,
        dates: [Date]
    ) throws -> MedicationReminderPlan {
        let plan = try requirePlan(id: planID)
        for time in plan.times { context.delete(time) }
        for occurrence in plan.occurrences { context.delete(occurrence) }

        plan.startDate = draft.startDate
        plan.durationDays = draft.durationDays
        plan.minimumIntervalMinutes = draft.minimumIntervalMinutes
        plan.snoozeMinutes = draft.snoozeMinutes
        plan.isActive = true
        plan.endedAt = nil
        plan.times = draft.times.map {
            MedicationReminderTimeModel(hour: $0.hour, minute: $0.minute, plan: plan)
        }
        plan.occurrences = dates.map {
            MedicationDoseOccurrence(scheduledAt: $0, plan: plan)
        }
        try context.save()
        return plan
    }

    func occurrences(on date: Date, calendar: Calendar) throws -> [MedicationDoseOccurrence] {
        let interval = calendar.dateInterval(of: .day, for: date)
        return try allOccurrences()
            .filter { occurrence in
                guard let interval else { return false }
                return interval.contains(occurrence.scheduledAt)
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func futureOccurrences(from date: Date) throws -> [MedicationDoseOccurrence] {
        try allOccurrences()
            .filter {
                ($0.status == .pending || $0.status == .snoozed)
                    && max($0.scheduledAt, $0.nextReminderAt ?? $0.scheduledAt) >= date
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func complete(occurrenceID: UUID, at date: Date) throws {
        let occurrence = try requireOccurrence(id: occurrenceID)
        guard occurrence.status != .completed else { return }
        occurrence.status = .completed
        occurrence.completedAt = date
        occurrence.nextReminderAt = nil
        try context.save()
    }

    func snooze(occurrenceID: UUID, until date: Date) throws {
        let occurrence = try requireOccurrence(id: occurrenceID)
        guard occurrence.status != .completed else { return }
        occurrence.status = .snoozed
        occurrence.nextReminderAt = date
        occurrence.snoozeCount += 1
        try context.save()
    }

    func end(planID: UUID, at date: Date) throws {
        let plan = try requirePlan(id: planID)
        plan.isActive = false
        plan.endedAt = date
        for occurrence in plan.occurrences where occurrence.status == .pending || occurrence.status == .snoozed {
            occurrence.status = .skipped
            occurrence.nextReminderAt = nil
        }
        try context.save()
    }

    func delete(planID: UUID) throws {
        let plan = try requirePlan(id: planID)
        context.delete(plan)
        try context.save()
    }

    private func makePlan(draft: MedicationReminderDraft, dates: [Date]) -> MedicationReminderPlan {
        let plan = MedicationReminderPlan(
            startDate: draft.startDate,
            durationDays: draft.durationDays,
            minimumIntervalMinutes: draft.minimumIntervalMinutes,
            snoozeMinutes: draft.snoozeMinutes
        )
        plan.times = draft.times.map {
            MedicationReminderTimeModel(hour: $0.hour, minute: $0.minute, plan: plan)
        }
        plan.occurrences = dates.map {
            MedicationDoseOccurrence(scheduledAt: $0, plan: plan)
        }
        return plan
    }

    private func requirePlan(id: UUID) throws -> MedicationReminderPlan {
        guard let plan = try allPlans().first(where: { $0.id == id }) else {
            throw MedicationReminderRepositoryError.planNotFound
        }
        return plan
    }

    private func requireOccurrence(id: UUID) throws -> MedicationDoseOccurrence {
        guard let occurrence = try allOccurrences().first(where: { $0.id == id }) else {
            throw MedicationReminderRepositoryError.occurrenceNotFound
        }
        return occurrence
    }

    private func allPlans() throws -> [MedicationReminderPlan] {
        try context.fetch(FetchDescriptor<MedicationReminderPlan>())
    }

    private func allOccurrences() throws -> [MedicationDoseOccurrence] {
        try context.fetch(FetchDescriptor<MedicationDoseOccurrence>())
    }
}
