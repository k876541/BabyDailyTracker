import Foundation

enum MainTabSelection: Int, Sendable {
    case today
    case history
    case growth
    case reminder
    case settings
}

enum MedicationReminderNavigation {
    static let selectedTabKey = "selectedMainTab"

    static func selectReminder(in defaults: UserDefaults = .standard) {
        defaults.set(MainTabSelection.reminder.rawValue, forKey: selectedTabKey)
    }

    static func selectToday(in defaults: UserDefaults = .standard) {
        defaults.set(MainTabSelection.today.rawValue, forKey: selectedTabKey)
    }

    static func selectedTab(in defaults: UserDefaults = .standard) -> MainTabSelection {
        MainTabSelection(rawValue: defaults.integer(forKey: selectedTabKey)) ?? .today
    }
}

enum MedicationNotificationResponseRoute: Equatable, Sendable {
    case completed(UUID)
    case snooze(UUID)
    case open(UUID)
    case ignored
}

enum MedicationNotificationPresentation: Hashable, Sendable {
    case banner
    case sound
}

enum MedicationNotificationResponseRouter {
    static let foregroundPresentation: Set<MedicationNotificationPresentation> = [.banner, .sound]

    static func route(
        actionIdentifier: String,
        occurrenceID: String?
    ) -> MedicationNotificationResponseRoute {
        guard let occurrenceID, let id = UUID(uuidString: occurrenceID) else { return .ignored }
        switch actionIdentifier {
        case UserNotificationMedicationScheduler.completedActionIdentifier:
            return .completed(id)
        case UserNotificationMedicationScheduler.snoozeActionIdentifier:
            return .snooze(id)
        case "com.apple.UNNotificationDefaultActionIdentifier":
            return .open(id)
        default:
            return .ignored
        }
    }
}

#if os(iOS)
import SwiftData
import UIKit
import UserNotifications

@MainActor
final class MedicationNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var coordinator: MedicationReminderCoordinator?
    private let scheduler = UserNotificationMedicationScheduler()

    func configure(container: ModelContainer) {
        let repository = SwiftDataMedicationReminderRepository(context: container.mainContext)
        coordinator = MedicationReminderCoordinator(repository: repository, scheduler: scheduler)
        scheduler.registerActions()
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor [weak self] in
            try? await self?.coordinator?.reconcile(now: .now)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let occurrenceID = response.notification.request.content.userInfo["occurrenceID"] as? String
        let route = MedicationNotificationResponseRouter.route(
            actionIdentifier: response.actionIdentifier,
            occurrenceID: occurrenceID
        )
        await handle(route)
    }

    private func handle(_ route: MedicationNotificationResponseRoute) async {
        switch route {
        case .completed(let id):
            guard let coordinator else { return }
            try? await coordinator.complete(occurrenceID: id, at: .now)
        case .snooze(let id):
            guard let coordinator else { return }
            try? await coordinator.snooze(occurrenceID: id, now: .now)
        case .open:
            MedicationReminderNavigation.selectReminder()
        case .ignored:
            break
        }
    }
}
#endif
