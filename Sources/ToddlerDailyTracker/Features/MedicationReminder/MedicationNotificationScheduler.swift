import Foundation
import UserNotifications

enum MedicationNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

enum MedicationSystemAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case provisional
    case ephemeral
    case denied
    case unknown
}

enum MedicationNotificationKind: Equatable, Sendable {
    case fixed
    case snooze
}

struct MedicationNotificationRequest: Equatable, Sendable {
    let identifier: String
    let occurrenceID: UUID
    let categoryIdentifier: String
    let fireDate: Date
    let kind: MedicationNotificationKind
}

struct MedicationNotificationActionDefinition: Equatable, Sendable {
    let identifier: String
    let title: String
}

struct MedicationNotificationCategoryDefinition: Equatable, Sendable {
    let identifier: String
    let actions: [MedicationNotificationActionDefinition]
}

@MainActor
protocol MedicationNotificationCenterClient: AnyObject {
    func authorizationStatus() async -> MedicationSystemAuthorization
    func requestAuthorization() async throws -> Bool
    func register(category: MedicationNotificationCategoryDefinition)
    func add(_ request: MedicationNotificationRequest) async throws
    func removePendingRequests(identifiers: [String])
}

@MainActor
protocol MedicationNotificationScheduling: AnyObject {
    func authorizationStatus() async -> MedicationNotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func registerActions()
    func scheduleFixed(occurrenceID: UUID, at date: Date) async throws
    func scheduleSnooze(occurrenceID: UUID, at date: Date) async throws
    func cancel(occurrenceIDs: [UUID])
}

@MainActor
final class UserNotificationMedicationScheduler: MedicationNotificationScheduling {
    static let categoryIdentifier = "MEDICATION_REMINDER"
    static let completedActionIdentifier = "MEDICATION_COMPLETED"
    static let snoozeActionIdentifier = "MEDICATION_SNOOZE"

    private let center: MedicationNotificationCenterClient

    init(center: MedicationNotificationCenterClient = SystemMedicationNotificationCenter()) {
        self.center = center
    }

    func authorizationStatus() async -> MedicationNotificationAuthorization {
        switch await center.authorizationStatus() {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied, .unknown:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization()
    }

    func registerActions() {
        center.register(category: MedicationNotificationCategoryDefinition(
            identifier: Self.categoryIdentifier,
            actions: [
                MedicationNotificationActionDefinition(
                    identifier: Self.completedActionIdentifier,
                    title: "已完成"
                ),
                MedicationNotificationActionDefinition(
                    identifier: Self.snoozeActionIdentifier,
                    title: "知道了"
                )
            ]
        ))
    }

    func scheduleFixed(occurrenceID: UUID, at date: Date) async throws {
        try await center.add(request(occurrenceID: occurrenceID, date: date, kind: .fixed))
    }

    func scheduleSnooze(occurrenceID: UUID, at date: Date) async throws {
        try await center.add(request(occurrenceID: occurrenceID, date: date, kind: .snooze))
    }

    func cancel(occurrenceIDs: [UUID]) {
        center.removePendingRequests(identifiers: occurrenceIDs.flatMap {
            [Self.fixedIdentifier(for: $0), Self.snoozeIdentifier(for: $0)]
        })
    }

    static func fixedIdentifier(for occurrenceID: UUID) -> String {
        "medication.fixed.\(occurrenceID.uuidString)"
    }

    static func snoozeIdentifier(for occurrenceID: UUID) -> String {
        "medication.snooze.\(occurrenceID.uuidString)"
    }

    private func request(
        occurrenceID: UUID,
        date: Date,
        kind: MedicationNotificationKind
    ) -> MedicationNotificationRequest {
        MedicationNotificationRequest(
            identifier: kind == .fixed
                ? Self.fixedIdentifier(for: occurrenceID)
                : Self.snoozeIdentifier(for: occurrenceID),
            occurrenceID: occurrenceID,
            categoryIdentifier: Self.categoryIdentifier,
            fireDate: date,
            kind: kind
        )
    }
}

@MainActor
private final class SystemMedicationNotificationCenter: MedicationNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> MedicationSystemAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func register(category: MedicationNotificationCategoryDefinition) {
        let actions = category.actions.map {
            UNNotificationAction(identifier: $0.identifier, title: $0.title)
        }
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: category.identifier,
                actions: actions,
                intentIdentifiers: []
            )
        ])
    }

    func add(_ request: MedicationNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = "餵藥提醒"
        content.body = request.kind == .fixed ? "到了預定的餵藥時間。" : "請再次確認是否已完成餵藥。"
        content.sound = .default
        content.categoryIdentifier = request.categoryIdentifier
        content.userInfo = ["occurrenceID": request.occurrenceID.uuidString]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        ))
    }

    func removePendingRequests(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
