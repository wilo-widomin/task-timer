//
//  FireSchedulerTests.swift
//  MenuTimerTests
//
//  Tests the pure firing-transition logic, including idempotency.
//

import XCTest
@testable import MenuTimer

final class FireSchedulerTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduler = FireScheduler()

    func testRunningItemNotYetDueIsUntouched() {
        var items = [TimerItem.timer(title: "X", duration: 100, now: epoch)]
        let fired = scheduler.process(items: &items, now: epoch.addingTimeInterval(50))

        XCTAssertTrue(fired.isEmpty)
        XCTAssertEqual(items[0].state, .running)
        XCTAssertFalse(items[0].didNotify)
    }

    func testDueItemFiresOnceAndTransitions() {
        var items = [TimerItem.timer(title: "X", duration: 100, now: epoch)]
        let fired = scheduler.process(items: &items, now: epoch.addingTimeInterval(100))

        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(items[0].state, .finished)
        XCTAssertTrue(items[0].didNotify)
    }

    func testFiringIsIdempotentAcrossRepeatedTicks() {
        var items = [TimerItem.timer(title: "X", duration: 10, now: epoch)]

        let first = scheduler.process(items: &items, now: epoch.addingTimeInterval(20))
        XCTAssertEqual(first.count, 1)

        let second = scheduler.process(items: &items, now: epoch.addingTimeInterval(21))
        XCTAssertTrue(second.isEmpty, "An already-notified item must not fire again")
    }

    func testMultipleDueItemsAllFire() {
        var items = [
            TimerItem.timer(title: "A", duration: 10, now: epoch),
            TimerItem.timer(title: "B", duration: 20, now: epoch),
            TimerItem.timer(title: "C", duration: 999, now: epoch),
        ]
        let fired = scheduler.process(items: &items, now: epoch.addingTimeInterval(30))

        XCTAssertEqual(Set(fired.map(\.title)), ["A", "B"])
        XCTAssertEqual(items.filter { $0.state == .finished }.count, 2)
    }
}
