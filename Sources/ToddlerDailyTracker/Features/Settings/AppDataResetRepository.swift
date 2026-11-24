import Foundation
import SwiftData

@MainActor
protocol AppDataResetRepository: AnyObject {
    func reset() throws -> [UUID]
}

@MainActor
final class SwiftDataAppDataResetRepository: AppDataResetRepository {
    private let context: ModelContext
    private let save: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        save: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.save = save
    }

    func reset() throws -> [UUID] {
        let occurrenceIDs = try context.fetch(FetchDescriptor<MedicationDoseOccurrence>())
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }

        do {
            try deleteAll(MedicationReminderPlan.self)
            try deleteAll(BabyProfile.self)
            try deleteAll(GrowthRecord.self)
            try deleteAll(MealRecord.self)
            try deleteAll(SleepRecord.self)
            try deleteAll(DiaperRecord.self)
            try save(context)
            return occurrenceIDs
        } catch {
            context.rollback()
            throw error
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
