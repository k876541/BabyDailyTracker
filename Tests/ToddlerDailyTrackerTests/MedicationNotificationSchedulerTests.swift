import Foundation
import Testing
@testable import ToddlerDailyTracker

@MainActor
@Suite("Medication notification scheduler")
struct MedicationNotificationSchedulerTests {
    @Test("Notification responses hop to the main actor before handling")
    func notificationResponsesHopToMainActor() async {
        let dispatcher = MedicationNotificationResponseDispatcher()
        let route = MedicationNotificationResponseRoute.open(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )
        var receivedRoute: MedicationNotificationResponseRoute?

        await withCheckedContinuation { continuation in
            dispatcher.dispatch(route) { received in
                MainActor.assertIsolated()
                receivedRoute = received
                continuation.resume()
            }
        }

        #expect(receivedRoute == route)
    }

    @Test("Fixed request contains occurrence ID and category")
    func fixedRequestContainsOccurrenceIDAndCategory() async throws {
        let center = RecordingNotificationCenter()
        let scheduler = UserNotificationMedicationScheduler(center: center)
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let fireDate = Date(timeIntervalSince1970: 1_800_000_000)

        try await scheduler.scheduleFixed(occurrenceID: id, at: fireDate)

        let request = try #require(center.requests.first)
        #expect(request.identifier == "medication.fixed.\(id.uuidString)")
        #expect(request.occurrenceID == id)
        #expect(request.categoryIdentifier == "MEDICATION_REMINDER")
        #expect(request.fireDate == fireDate)
        #expect(request.kind == .fixed)
    }

    @Test("Snooze uses a stable replacement identifier")
    func snoozeUsesStableReplacementIdentifier() async throws {
        let center = RecordingNotificationCenter()
        let scheduler = UserNotificationMedicationScheduler(center: center)
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        try await scheduler.scheduleSnooze(occurrenceID: id, at: Date(timeIntervalSince1970: 100))
        try await scheduler.scheduleSnooze(occurrenceID: id, at: Date(timeIntervalSince1970: 200))

        #expect(center.requests.map(\.identifier) == [
            "medication.snooze.\(id.uuidString)",
            "medication.snooze.\(id.uuidString)"
        ])
    }

    @Test("Cancel removes fixed and snooze requests")
    func cancelRemovesFixedAndSnoozeRequests() {
        let center = RecordingNotificationCenter()
        let scheduler = UserNotificationMedicationScheduler(center: center)
        let first = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let second = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        scheduler.cancel(occurrenceIDs: [first, second])

        #expect(center.removedIdentifiers == [
            "medication.fixed.\(first.uuidString)",
            "medication.snooze.\(first.uuidString)",
            "medication.fixed.\(second.uuidString)",
            "medication.snooze.\(second.uuidString)"
        ])
    }

    @Test("Register actions includes completed and snooze")
    func registersCompletedAndSnoozeActions() throws {
        let center = RecordingNotificationCenter()
        let scheduler = UserNotificationMedicationScheduler(center: center)

        scheduler.registerActions()

        let category = try #require(center.category)
        #expect(category.identifier == "MEDICATION_REMINDER")
        #expect(category.actions == [
            MedicationNotificationActionDefinition(identifier: "MEDICATION_COMPLETED", title: "已完成"),
            MedicationNotificationActionDefinition(identifier: "MEDICATION_SNOOZE", title: "知道了")
        ])
    }

    @Test("Authorization states map without force unwrap", arguments: [
        (MedicationSystemAuthorization.notDetermined, MedicationNotificationAuthorization.notDetermined),
        (.authorized, .authorized),
        (.provisional, .authorized),
        (.ephemeral, .authorized),
        (.denied, .denied),
        (.unknown, .denied)
    ])
    func authorizationStatesMapWithoutForceUnwrap(
        system: MedicationSystemAuthorization,
        expected: MedicationNotificationAuthorization
    ) async {
        let center = RecordingNotificationCenter()
        center.authorization = system
        let scheduler = UserNotificationMedicationScheduler(center: center)

        #expect(await scheduler.authorizationStatus() == expected)
    }
}

@MainActor
private final class RecordingNotificationCenter: MedicationNotificationCenterClient {
    var authorization = MedicationSystemAuthorization.notDetermined
    var authorizationResult = true
    var requests: [MedicationNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var category: MedicationNotificationCategoryDefinition?

    func authorizationStatus() async -> MedicationSystemAuthorization { authorization }
    func requestAuthorization() async throws -> Bool { authorizationResult }
    func register(category: MedicationNotificationCategoryDefinition) { self.category = category }
    func add(_ request: MedicationNotificationRequest) async throws { requests.append(request) }
    func removePendingRequests(identifiers: [String]) { removedIdentifiers = identifiers }
}
