import Foundation
import SwiftData

@MainActor
protocol GrowthRepository {
    func fetch() throws -> [GrowthRecord]
    func save(_ record: GrowthRecord) throws
    func delete(_ record: GrowthRecord) throws
}

@MainActor
final class SwiftDataGrowthRepository: GrowthRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func fetch() throws -> [GrowthRecord] {
        let descriptor = FetchDescriptor<GrowthRecord>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func save(_ record: GrowthRecord) throws {
        try GrowthInputValidator.validate(height: record.heightCM, weight: record.weightKG)
        if record.modelContext == nil { context.insert(record) }
        try context.save()
    }

    func delete(_ record: GrowthRecord) throws {
        context.delete(record)
        try context.save()
    }
}

enum BabyProfileRepositoryError: Error, Equatable {
    case profileAlreadyExists
}

@MainActor
protocol BabyProfileRepository {
    func fetchProfile() throws -> BabyProfile?
    func createProfile(name: String, birthday: Date) throws -> BabyProfile
    func updateProfile(_ profile: BabyProfile) throws
}

@MainActor
final class SwiftDataBabyProfileRepository: BabyProfileRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func fetchProfile() throws -> BabyProfile? {
        try context.fetch(FetchDescriptor<BabyProfile>()).first
    }

    func createProfile(name: String, birthday: Date) throws -> BabyProfile {
        guard try fetchProfile() == nil else { throw BabyProfileRepositoryError.profileAlreadyExists }
        let profile = BabyProfile(name: name, birthday: birthday)
        context.insert(profile)
        try context.save()
        return profile
    }

    func updateProfile(_ profile: BabyProfile) throws { try context.save() }
}

@MainActor
final class DailyRecordRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func meals() throws -> [MealRecord] {
        try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]))
    }

    func sleeps() throws -> [SleepRecord] {
        try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }

    func diapers() throws -> [DiaperRecord] {
        try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]))
    }

    func save<T: PersistentModel>(_ model: T) throws {
        if model.modelContext == nil { context.insert(model) }
        try context.save()
    }

    func delete<T: PersistentModel>(_ model: T) throws {
        context.delete(model)
        try context.save()
    }
}

