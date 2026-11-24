import Foundation
import SwiftData

@MainActor
protocol AppDataResetRepository: AnyObject {
    func reset() throws -> [UUID]
}

@MainActor
final class SwiftDataAppDataResetRepository: AppDataResetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func reset() throws -> [UUID] {
        let occurrenceIDs = try context.fetch(FetchDescriptor<MedicationDoseOccurrence>())
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }

        try deleteAll(MedicationReminderPlan.self)
        try deleteAll(BabyProfile.self)
        try deleteAll(GrowthRecord.self)
        try deleteAll(MealRecord.self)
        try deleteAll(SleepRecord.self)
        try deleteAll(DiaperRecord.self)
        try context.save()
        return occurrenceIDs
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
