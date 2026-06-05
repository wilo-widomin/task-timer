//
//  TimeFormattingTests.swift
//  MenuTimerTests
//

import XCTest
@testable import MenuTimer

final class TimeFormattingTests: XCTestCase {

    func testCountdownUnderOneHour() {
        XCTAssertEqual(TimeFormatting.countdown(0), "00:00")
        XCTAssertEqual(TimeFormatting.countdown(9), "00:09")
        XCTAssertEqual(TimeFormatting.countdown(65), "01:05")
        XCTAssertEqual(TimeFormatting.countdown(249), "04:09")
    }

    func testCountdownOverOneHour() {
        XCTAssertEqual(TimeFormatting.countdown(3_600), "1:00:00")
        XCTAssertEqual(TimeFormatting.countdown(3_729), "1:02:09")
    }

    func testCountdownClampsNegative() {
        XCTAssertEqual(TimeFormatting.countdown(-42), "00:00")
    }

    func testCountdownRoundsUpPartialSecond() {
        // 4.2s remaining should still read 5s, not 4s, so the label doesn't
        // appear to skip the final second.
        XCTAssertEqual(TimeFormatting.countdown(4.2), "00:05")
    }

    func testDurationLabel() {
        XCTAssertEqual(TimeFormatting.durationLabel(45), "45 s")
        XCTAssertEqual(TimeFormatting.durationLabel(60), "1 min")
        XCTAssertEqual(TimeFormatting.durationLabel(1_500), "25 min")
        XCTAssertEqual(TimeFormatting.durationLabel(5_400), "1 h 30 min")
        XCTAssertEqual(TimeFormatting.durationLabel(0), "0 s")
    }
}
