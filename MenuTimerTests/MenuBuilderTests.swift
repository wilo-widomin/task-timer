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
        MenuBuilder.Actions(
            addTimer: {},
            addAlarm: {},
            addStopwatch: {},
            addPomodoro: {},
            about: {},
            quit: {},
            delete: delete,
            togglePause: { _ in }
        )
    }

    func testEmptyStateShowsPlaceholder() {
        let menu = NSMenu()
        let rows = MenuBuilder().populate(menu, items: [], now: epoch, actions: noopActions())

        XCTAssertTrue(rows.isEmpty)
        // Add Timer, Add Alarm, Add Pomodoro, Add Stopwatch, sep,
        // placeholder, sep, About, Quit = 9
        XCTAssertEqual(menu.items.count, 9)
        XCTAssertEqual(menu.items.first?.title, "Add Timer…")
        XCTAssertEqual(menu.items.last?.title, "Quit Menu Timer")
        let placeholder = menu.items[5]
        XCTAssertEqual(placeholder.title, "No active timers, alarms, or stopwatches")
        XCTAssertFalse(placeholder.isEnabled)
    }

    func testTimerSectionHeaderWhenOnlyTimers() {
        let items = [TimerItem.timer(title: "A", duration: 60, now: epoch)]
        let menu = NSMenu()
        let rows = MenuBuilder().populate(menu, items: items, now: epoch, actions: noopActions())

        XCTAssertEqual(rows.count, 1)
        // 5 leading + "  Timers  " header (disabled) + 1 row + sep + About + Quit = 10
        XCTAssertEqual(menu.items.count, 10)
        XCTAssertEqual(menu.items[5].title, "  Timers  ")
        XCTAssertFalse(menu.items[5].isEnabled)
        XCTAssertNotNil(menu.items[6].view as? TimerRowView)
    }

    func testSectionsGroupedByKind() {
        let items = [
            TimerItem.stopwatch(title: "S", now: epoch),
            TimerItem.timer(title: "T", duration: 60, now: epoch),
            TimerItem.alarm(title: "A", fireDate: epoch.addingTimeInterval(3_600), now: epoch),
        ]
        let menu = NSMenu()
        let rows = MenuBuilder().populate(menu, items: items, now: epoch, actions: noopActions())

        XCTAssertEqual(rows.count, 3)
        // 5 leading + "  Timers  " + T + sep + "  Alarms  " + A + sep + "  Stopwatches  " + S + sep + About + Quit = 16
        XCTAssertEqual(menu.items.count, 16)
        let titleIndex = menu.items.firstIndex { $0.title == "  Timers  " }
        let alarmsIndex = menu.items.firstIndex { $0.title == "  Alarms  " }
        let stopwatchIndex = menu.items.firstIndex { $0.title == "  Stopwatches  " }

        XCTAssertNotNil(titleIndex)
        XCTAssertNotNil(alarmsIndex)
        XCTAssertNotNil(stopwatchIndex)
        XCTAssertLessThan(titleIndex!, alarmsIndex!)
        XCTAssertLessThan(alarmsIndex!, stopwatchIndex!)
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
        XCTAssertEqual(menu.items.count, 9)
        XCTAssertEqual(firstCount, 10)
    }
}