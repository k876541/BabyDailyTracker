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

