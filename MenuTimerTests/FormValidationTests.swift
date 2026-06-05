//
//  FormValidationTests.swift
//  MenuTimerTests
//

import XCTest
@testable import MenuTimer

final class FormValidationTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Duration

    func testDurationConvertsHoursAndMinutes() {
        XCTAssertEqual(FormValidation.duration(hours: 1, minutes: 30), 5_400)
        XCTAssertEqual(FormValidation.duration(hours: 0, minutes: 5), 300)
    }

    func testDurationClampsNegatives() {
        XCTAssertEqual(FormValidation.duration(hours: -1, minutes: -10), 0)
    }

    // MARK: - Title

    func testNormalizedTitleTrimsWhitespace() {
        XCTAssertEqual(FormValidation.normalizedTitle("  Tea \n"), "Tea")
    }

    // MARK: - Timer validity

    func testTimerRequiresPositiveDuration() {
        XCTAssertFalse(FormValidation.isValidTimer(hours: 0, minutes: 0, title: "X"))
        XCTAssertTrue(FormValidation.isValidTimer(hours: 0, minutes: 1, title: "X"))
    }

    func testTimerRequiresNonEmptyTitle() {
        XCTAssertFalse(FormValidation.isValidTimer(hours: 0, minutes: 5, title: "   "))
        XCTAssertTrue(FormValidation.isValidTimer(hours: 0, minutes: 5, title: "Pasta"))
    }

    // MARK: - Alarm validity

    func testAlarmRequiresFutureDate() {
        XCTAssertFalse(FormValidation.isValidAlarm(fireDate: now, title: "X", now: now))
        XCTAssertFalse(FormValidation.isValidAlarm(fireDate: now.addingTimeInterval(-10), title: "X", now: now))
        XCTAssertTrue(FormValidation.isValidAlarm(fireDate: now.addingTimeInterval(60), title: "X", now: now))
    }

    func testAlarmRequiresNonEmptyTitle() {
        let future = now.addingTimeInterval(60)
        XCTAssertFalse(FormValidation.isValidAlarm(fireDate: future, title: "", now: now))
        XCTAssertTrue(FormValidation.isValidAlarm(fireDate: future, title: "Standup", now: now))
    }
}
