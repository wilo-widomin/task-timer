//
//  TimerItemTests.swift
//  MenuTimerTests
//
//  Unit tests for the core domain model and its derived-time logic.
//

import XCTest
@testable import MenuTimer

final class TimerItemTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Factories

    func testTimerFactorySetsFireDateFromDuration() {
        let item = TimerItem.timer(title: "Tea", duration: 300, now: epoch)

        XCTAssertEqual(item.kind, .timer)
        XCTAssertEqual(item.title, "Tea")
        XCTAssertEqual(item.createdAt, epoch)
        XCTAssertEqual(item.fireDate, epoch.addingTimeInterval(300))
        XCTAssertEqual(item.configuredDuration, 300)
        XCTAssertEqual(item.state, .running)
        XCTAssertFalse(item.didNotify)
    }

    func testAlarmFactoryUsesAbsoluteFireDate() {
        let fire = epoch.addingTimeInterval(3_600)
        let item = TimerItem.alarm(title: "Meeting", fireDate: fire, now: epoch)

        XCTAssertEqual(item.kind, .alarm)
        XCTAssertEqual(item.fireDate, fire)
        XCTAssertNil(item.configuredDuration)
        XCTAssertEqual(item.state, .running)
    }

    // MARK: - remaining(at:)

    func testRemainingForRunningItem() {
        let item = TimerItem.timer(title: "X", duration: 120, now: epoch)
        XCTAssertEqual(item.remaining(at: epoch), 120, accuracy: 0.0001)
        XCTAssertEqual(item.remaining(at: epoch.addingTimeInterval(50)), 70, accuracy: 0.0001)
    }

    func testRemainingCanGoNegativeBeforeReconciliation() {
        let item = TimerItem.timer(title: "X", duration: 10, now: epoch)
        XCTAssertEqual(item.remaining(at: epoch.addingTimeInterval(15)), -5, accuracy: 0.0001)
    }

    func testRemainingIsZeroWhenFinished() {
        var item = TimerItem.timer(title: "X", duration: 120, now: epoch)
        item.state = .finished
        XCTAssertEqual(item.remaining(at: epoch), 0)
    }

    // MARK: - hasFired(at:)

    func testHasFiredAtOrAfterFireDate() {
        let item = TimerItem.timer(title: "X", duration: 10, now: epoch)
        XCTAssertFalse(item.hasFired(at: epoch))
        XCTAssertFalse(item.hasFired(at: epoch.addingTimeInterval(9)))
        XCTAssertTrue(item.hasFired(at: epoch.addingTimeInterval(10)))
        XCTAssertTrue(item.hasFired(at: epoch.addingTimeInterval(11)))
    }

    func testFinishedItemHasNotFired() {
        var item = TimerItem.timer(title: "X", duration: 10, now: epoch)
        item.state = .finished
        XCTAssertFalse(item.hasFired(at: epoch.addingTimeInterval(100)))
    }
}
