import Foundation
import Observation

@MainActor
@Observable
final class MedicationReminderViewModel {
    private let repository: MedicationReminderRepository
    private let coordinator: MedicationReminderCoordinating
    private let now: () -> Date
    private let calendar: Calendar

    private(set) var activePlan: MedicationReminderPlan?
    private(set) var todayOccurrences: [MedicationDoseOccurrence] = []
    var draft: MedicationReminderDraft
    private(set) var isSaving = false
    var errorMessage: String?
    private(set) var intervalWarning: String?

    init(
        repository: MedicationReminderRepository,
        coordinator: MedicationReminderCoordinating,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.coordinator = coordinator
        self.now = now
        self.calendar = calendar
        self.draft = MedicationReminderDraft(
            startDate: calendar.startOfDay(for: now()),
            durationDays: 1,
            times: [
                MedicationReminderTime(hour: 9, minute: 0),
                MedicationReminderTime(hour: 13, minute: 0),
                MedicationReminderTime(hour: 17, minute: 0)
            ],
            minimumIntervalMinutes: 240,
            snoozeMinutes: 5
        )
    }

    var maximumDurationDays: Int {
        MedicationScheduleBuilder.maximumOccurrences / max(draft.times.count, 1)
    }

    func load() {
        do {
            activePlan = try repository.activePlan()
            todayOccurrences = try repository.occurrences(on: now(), calendar: calendar)
            if let activePlan {
                draft = MedicationReminderDraft(
                    startDate: activePlan.startDate,
                    durationDays: activePlan.durationDays,
                    times: activePlan.times
                        .map { MedicationReminderTime(hour: $0.hour, minute: $0.minute) }
                        .sorted(by: Self.sortTimes),
                    minimumIntervalMinutes: activePlan.minimumIntervalMinutes,
                    snoozeMinutes: activePlan.snoozeMinutes
                )
            }
            intervalWarning = makeIntervalWarning()
        } catch {
            errorMessage = "無法讀取餵藥提醒，請稍後再試。"
        }
    }

    func save() async {
        guard !isSaving else { return }
        do {
            _ = try MedicationScheduleBuilder.occurrenceDates(for: draft, calendar: calendar)
        } catch {
            errorMessage = message(for: error)
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            if let activePlan {
                try await coordinator.update(planID: activePlan.id, draft: draft)
            } else {
                try await coordinator.create(draft)
            }
            errorMessage = nil
            load()
        } catch MedicationReminderCoordinatorError.notificationsDenied {
            errorMessage = "請允許通知權限，才能建立餵藥提醒。"
        } catch MedicationReminderCoordinatorError.occurrenceInPast {
            errorMessage = "提醒時間必須晚於現在。"
        } catch {
            errorMessage = "無法儲存餵藥提醒，請稍後再試。"
        }
    }

    func end() async {
        guard let activePlan else { return }
        do {
            try await coordinator.end(planID: activePlan.id, at: now())
            load()
        } catch {
            errorMessage = "無法提前結束提醒，請稍後再試。"
        }
    }

    func delete() async {
        guard let activePlan else { return }
        do {
            try await coordinator.delete(planID: activePlan.id)
            self.activePlan = nil
            todayOccurrences = []
            intervalWarning = nil
        } catch {
            errorMessage = "無法刪除提醒，請稍後再試。"
        }
    }

    private func makeIntervalWarning() -> String? {
        guard let plan = activePlan else { return nil }
        let sorted = todayOccurrences.sorted { $0.scheduledAt < $1.scheduledAt }
        for occurrence in sorted where occurrence.status == .completed {
            guard let completedAt = occurrence.completedAt,
                  let next = sorted.first(where: { $0.scheduledAt > occurrence.scheduledAt }) else {
                continue
            }
            let gap = next.scheduledAt.timeIntervalSince(completedAt) / 60
            if gap >= 0, gap < Double(plan.minimumIntervalMinutes) {
                let components = calendar.dateComponents([.hour, .minute], from: next.scheduledAt)
                let time = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
                return "本次完成時間距離 \(time) 的提醒少於 \(plan.minimumIntervalMinutes / 60) 小時。"
            }
        }
        return nil
    }

    private func message(for error: Error) -> String {
        switch error {
        case MedicationScheduleValidationError.intervalTooShort(let minutes):
            return "提醒時間至少需間隔 \(minutes / 60) 小時。"
        case MedicationScheduleValidationError.tooManyOccurrences:
            return "固定提醒最多可設定 48 次。"
        case MedicationScheduleValidationError.noReminderTimes:
            return "請至少設定一個提醒時間。"
        case MedicationScheduleValidationError.invalidDuration:
            return "提醒天數必須大於 0。"
        case MedicationScheduleValidationError.duplicateTime:
            return "提醒時間不可重複。"
        default:
            return "提醒設定不正確，請重新確認。"
        }
    }

    private static func sortTimes(_ left: MedicationReminderTime, _ right: MedicationReminderTime) -> Bool {
        (left.hour, left.minute) < (right.hour, right.minute)
    }
}
