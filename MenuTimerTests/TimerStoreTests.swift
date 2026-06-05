//
//  TimerStoreTests.swift
//  MenuTimerTests
//
//  Tests the store's mutation, firing, notification and persistence behaviour.
//

import XCTest
@testable import MenuTimer

@MainActor
final class TimerStoreTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeStore(
        initial: PersistedStore = .empty
    ) -> (TimerStore, InMemoryPersistence, SpyNotificationService) {
        let persistence = InMemoryPersistence(initial: initial)
        let notifier = SpyNotificationService()
        let store = TimerStore(persistence: persistence, notificationService: notifier)
        return (store, persistence, notifier)
    }

    // MARK: - Mutations

    func testAddTimerAppendsRunningItem() {
        let (store, _, _) = makeStore()
        store.addTimer(title: "Tea", duration: 300, now: epoch)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].title, "Tea")
        XCTAssertEqual(store.items[0].state, .running)
    }

    func testRemoveDeletesById() {
        let (store, _, _) = makeStore()
        let item = store.addTimer(title: "X", duration: 60, now: epoch)
        store.addTimer(title: "Y", duration: 90, now: epoch)

        store.remove(id: item.id)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Y")
    }

    func testItemsAreSortedBySoonestFireDate() {
        let (store, _, _) = makeStore()
        store.addTimer(title: "Late", duration: 500, now: epoch)
        store.addTimer(title: "Soon", duration: 10, now: epoch)

        XCTAssertEqual(store.items.map(\.title), ["Soon", "Late"])
    }

    // MARK: - Tick / firing

    func testTickFiresDueItemAndNotifies() {
        let (store, _, notifier) = makeStore()
        store.addTimer(title: "Done", duration: 10, now: epoch)

        store.tick(now: epoch.addingTimeInterval(10))

        XCTAssertEqual(store.items[0].state, .finished)
        XCTAssertEqual(notifier.posted.map(\.title), ["Done"])
    }

    func testTickIsNoOpWhenNothingDue() {
        let (store, _, notifier) = makeStore()
        store.addTimer(title: "X", duration: 100, now: epoch)

        store.tick(now: epoch.addingTimeInterval(50))

        XCTAssertEqual(store.items[0].state, .running)
        XCTAssertTrue(notifier.posted.isEmpty)
    }

    func testRepeatedTickDoesNotDoubleNotify() {
        let (store, _, notifier) = makeStore()
        store.addTimer(title: "X", duration: 10, now: epoch)

        store.tick(now: epoch.addingTimeInterval(11))
        store.tick(now: epoch.addingTimeInterval(12))

        XCTAssertEqual(notifier.posted.count, 1)
    }

    // MARK: - Loading & reconciliation

    func testLoadReconcilesMissedFirings() async {
        // Item that fired while the app was closed.
        let missed = TimerItem.timer(title: "Missed", duration: 10, now: epoch)
        let initial = PersistedStore(items: [missed])
        let (store, _, notifier) = makeStore(initial: initial)

        await store.load(now: epoch.addingTimeInterval(60))

        XCTAssertEqual(store.items[0].state, .finished)
        XCTAssertEqual(notifier.posted.map(\.title), ["Missed"])
    }

    func testLoadDoesNotReNotifyAlreadyNotifiedItems() async {
        var alreadyDone = TimerItem.timer(title: "Old", duration: 10, now: epoch)
        alreadyDone.state = .finished
        alreadyDone.didNotify = true
        let (store, _, notifier) = makeStore(initial: PersistedStore(items: [alreadyDone]))

        await store.load(now: epoch.addingTimeInterval(60))

        XCTAssertTrue(notifier.posted.isEmpty)
    }

    // MARK: - Persistence integration

    func testMutationsPersist() async {
        let persistence = InMemoryPersistence()
        let notifier = SpyNotificationService()
        let store = TimerStore(persistence: persistence, notificationService: notifier)

        store.addTimer(title: "Persist me", duration: 60, now: epoch)

        // Allow the detached save Task to complete.
        try? await Task.sleep(nanoseconds: 50_000_000)

        let saved = await persistence.stored
        XCTAssertEqual(saved.items.map(\.title), ["Persist me"])
    }
}
