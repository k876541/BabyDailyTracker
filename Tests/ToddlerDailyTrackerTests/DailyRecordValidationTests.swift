import Foundation
import Testing
@testable import ToddlerDailyTracker

struct DailyRecordValidationTests {
    @Test("Sleep ending before it starts is rejected")
    func reversedSleepIsRejected() {
        let start = Date(timeIntervalSince1970: 200)
        let end = Date(timeIntervalSince1970: 100)
        #expect(throws: DailyRecordValidationError.invalidSleepRange) {
            try DailyRecordValidator.validateSleep(start: start, end: end)
        }
    }

    @Test("A chronological sleep range is valid")
    func chronologicalSleepIsValid() throws {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)
        #expect(throws: Never.self) {
            try DailyRecordValidator.validateSleep(start: start, end: end)
        }
    }
}
