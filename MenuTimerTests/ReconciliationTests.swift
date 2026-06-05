//
//  ReconciliationTests.swift
//  MenuTimerTests
//
//  Verifies drift/wake reconciliation: when wall-clock time jumps ahead (sleep,
//  missed ticks), elapsed items fire exactly once.
//

import XCTest
@testable import MenuTimer

@MainActor
final class ReconciliationTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    func testReconcileFiresElapsedItemsAfterTimeJump() async {
        let persistence = InMemoryPersistence()
        let notifier = SpyNotificationService()
        let store = TimerStore(persistence: persistence, notificationService: notifier)

        store.addTimer(title: "Short", duration: 30, now: epoch)
        store.addTimer(title: "Long", duration: 3_600, now: epoch)

        // Simulate the machine sleeping for 5 minutes: a single reconcile far in
        // the future stands in for the missed per-second ticks.
        store.reconcile(now: epoch.addingTimeInterval(300))

        XCTAssertEqual(notifier.posted.map(\.title), ["Short"])
        XCTAssertEqual(store.items.first(where: { $0.title == "Short" })?.state, .finished)
        XCTAssertEqual(store.items.first(where: { $0.title == "Long" })?.state, .running)
    }

    func testRepeatedReconcileDoesNotDoubleFire() async {
        let persistence = InMemoryPersistence()
        let notifier = SpyNotificationService()
        let store = TimerStore(persistence: persistence, notificationService: notifier)
        store.addTimer(title: "X", duration: 10, now: epoch)

        store.reconcile(now: epoch.addingTimeInterval(100))
        store.reconcile(now: epoch.addingTimeInterval(200))

        XCTAssertEqual(notifier.posted.count, 1)
    }
}
