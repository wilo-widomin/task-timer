//
//  MenuBuilderTests.swift
//  MenuTimerTests
//
//  Verifies menu structure, the dynamic section, and delete wiring.
//

import XCTest
import AppKit
@testable import MenuTimer

@MainActor
final class MenuBuilderTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func noopActions(delete: @escaping (TimerItem.ID) -> Void = { _ in }) -> MenuBuilder.Actions {
        MenuBuilder.Actions(addTimer: {}, addAlarm: {}, about: {}, quit: {}, delete: delete)
    }

    func testEmptyStateShowsPlaceholder() {
        let menu = NSMenu()
        let rows = MenuBuilder().populate(menu, items: [], now: epoch, actions: noopActions())

        XCTAssertTrue(rows.isEmpty)
        // Add Timer, Add Alarm, sep, placeholder, sep, About, Quit
        XCTAssertEqual(menu.items.count, 7)
        XCTAssertEqual(menu.items.first?.title, "Add Timer…")
        XCTAssertEqual(menu.items.last?.title, "Quit Menu Timer")
        let placeholder = menu.items[3]
        XCTAssertEqual(placeholder.title, "No active timers or alarms")
        XCTAssertFalse(placeholder.isEnabled)
    }

    func testDynamicRowsCreatedPerItem() {
        let items = [
            TimerItem.timer(title: "A", duration: 60, now: epoch),
            TimerItem.alarm(title: "B", fireDate: epoch.addingTimeInterval(3_600), now: epoch),
        ]
        let menu = NSMenu()
        let rows = MenuBuilder().populate(menu, items: items, now: epoch, actions: noopActions())

        XCTAssertEqual(rows.count, 2)
        // 3 fixed leading items + 2 rows + 3 fixed trailing items = 8
        XCTAssertEqual(menu.items.count, 8)
        XCTAssertNotNil(menu.items[3].view as? TimerRowView)
        XCTAssertNotNil(menu.items[4].view as? TimerRowView)
    }

    func testDeleteClosureReceivesItemID() {
        let item = TimerItem.timer(title: "Z", duration: 60, now: epoch)
        var deleted: TimerItem.ID?
        let menu = NSMenu()
        let rows = MenuBuilder().populate(
            menu,
            items: [item],
            now: epoch,
            actions: noopActions(delete: { deleted = $0 })
        )

        rows[item.id]?.onDelete?()
        XCTAssertEqual(deleted, item.id)
    }

    func testPopulateClearsPreviousItems() {
        let menu = NSMenu()
        let builder = MenuBuilder()
        builder.populate(menu, items: [.timer(title: "A", duration: 60, now: epoch)], now: epoch, actions: noopActions())
        let firstCount = menu.items.count

        builder.populate(menu, items: [], now: epoch, actions: noopActions())
        XCTAssertEqual(menu.items.count, 7)
        XCTAssertEqual(firstCount, 7)
    }
}
