import Foundation
import SwiftData

@Model
final class BabyProfile {
    var name: String
    var birthday: Date

    init(name: String = "寶寶", birthday: Date = .now) {
        self.name = name
        self.birthday = birthday
    }
}

@Model
final class GrowthRecord {
    var measuredAt: Date
    var heightCM: Double?
    var weightKG: Double?

    init(measuredAt: Date, heightCM: Double? = nil, weightKG: Double? = nil) {
        self.measuredAt = measuredAt
        self.heightCM = heightCM
        self.weightKG = weightKG
    }

    var sample: GrowthSample {
        GrowthSample(measuredAt: measuredAt, heightCM: heightCM, weightKG: weightKG)
    }
}

@Model
final class MealRecord {
    var recordedAt: Date
    var kind: String
    var content: String
    var note: String
    var amount: Double?
    var unit: String?

    init(recordedAt: Date, kind: String, content: String, note: String = "", amount: Double? = nil, unit: String? = nil) {
        self.recordedAt = recordedAt
        self.kind = kind
        self.content = content
        self.note = note
        self.amount = amount
        self.unit = unit
    }
}

@Model
final class SleepRecord {
    var startedAt: Date
    var endedAt: Date?
    var note: String

    init(startedAt: Date, endedAt: Date? = nil, note: String = "") {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
    }
}

@Model
final class DiaperRecord {
    var recordedAt: Date
    var condition: String
    var note: String

    init(recordedAt: Date, condition: String, note: String = "") {
        self.recordedAt = recordedAt
        self.condition = condition
        self.note = note
    }
}

enum MedicationDoseStatus: String, Codable, Sendable {
    case pending
    case snoozed
    case completed
    case skipped
}

@Model
final class MedicationReminderPlan {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var durationDays: Int
    var minimumIntervalMinutes: Int
    var snoozeMinutes: Int
    var isActive: Bool
    var createdAt: Date
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \MedicationReminderTimeModel.plan)
    var times: [MedicationReminderTimeModel]
    @Relationship(deleteRule: .cascade, inverse: \MedicationDoseOccurrence.plan)
    var occurrences: [MedicationDoseOccurrence]

    init(
        id: UUID = UUID(),
        startDate: Date,
        durationDays: Int,
        minimumIntervalMinutes: Int,
        snoozeMinutes: Int,
        isActive: Bool = true,
        createdAt: Date = .now,
        endedAt: Date? = nil,
        times: [MedicationReminderTimeModel] = [],
        occurrences: [MedicationDoseOccurrence] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.durationDays = durationDays
        self.minimumIntervalMinutes = minimumIntervalMinutes
        self.snoozeMinutes = snoozeMinutes
        self.isActive = isActive
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.times = times
        self.occurrences = occurrences
    }
}

@Model
final class MedicationReminderTimeModel {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    var plan: MedicationReminderPlan?

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        plan: MedicationReminderPlan? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.plan = plan
    }
}

@Model
final class MedicationDoseOccurrence {
    @Attribute(.unique) var id: UUID
    var scheduledAt: Date
    var statusRawValue: String
    var completedAt: Date?
    var nextReminderAt: Date?
    var snoozeCount: Int
    var plan: MedicationReminderPlan?

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        status: MedicationDoseStatus = .pending,
        completedAt: Date? = nil,
        nextReminderAt: Date? = nil,
        snoozeCount: Int = 0,
        plan: MedicationReminderPlan? = nil
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.statusRawValue = status.rawValue
        self.completedAt = completedAt
        self.nextReminderAt = nextReminderAt
        self.snoozeCount = snoozeCount
        self.plan = plan
    }

    var status: MedicationDoseStatus {
        get { MedicationDoseStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }
}

