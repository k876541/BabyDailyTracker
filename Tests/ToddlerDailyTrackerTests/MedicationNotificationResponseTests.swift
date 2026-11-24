import Foundation
import Testing
@testable import ToddlerDailyTracker

@Suite("Medication notification responses")
struct MedicationNotificationResponseTests {
    private let occurrenceID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    @Test("Completed action routes the occurrence ID")
    func completedActionRoutesOccurrenceID() {
        #expect(MedicationNotificationResponseRouter.route(
            actionIdentifier: "MEDICATION_COMPLETED",
            occurrenceID: occurrenceID.uuidString
        ) == .completed(occurrenceID))
    }

    @Test("Snooze action routes the occurrence ID")
    func snoozeActionRoutesOccurrenceID() {
        #expect(MedicationNotificationResponseRouter.route(
            actionIdentifier: "MEDICATION_SNOOZE",
            occurrenceID: occurrenceID.uuidString
        ) == .snooze(occurrenceID))
    }

    @Test("Unknown action is ignored")
    func unknownActionIsIgnored() {
        #expect(MedicationNotificationResponseRouter.route(
            actionIdentifier: "UNKNOWN",
            occurrenceID: occurrenceID.uuidString
        ) == .ignored)
    }

    @Test("Malformed occurrence ID is ignored")
    func malformedOccurrenceIDIsIgnored() {
        #expect(MedicationNotificationResponseRouter.route(
            actionIdentifier: "MEDICATION_COMPLETED",
            occurrenceID: "not-a-uuid"
        ) == .ignored)
    }

    @Test("Foreground presentation requests banner and sound")
    func foregroundPresentationRequestsBannerAndSound() {
        #expect(MedicationNotificationResponseRouter.foregroundPresentation == [.banner, .sound])
    }
}
