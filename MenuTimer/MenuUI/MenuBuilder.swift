//
//  MenuBuilder.swift
//  MenuTimer
//
//  Builds the status-item menu: fixed commands plus a dynamic section of one
//  custom row per active item.
//

import AppKit

/// Constructs the `NSMenu` for the status item.
@MainActor
struct MenuBuilder {

    /// The set of user actions the menu can trigger.
    struct Actions {
        let addTimer: () -> Void
        let addAlarm: () -> Void
        let addStopwatch: () -> Void
        let about: () -> Void
        let quit: () -> Void
        let delete: (TimerItem.ID) -> Void
        let togglePause: (TimerItem.ID) -> Void
    }

    /// Repopulates `menu` in place to reflect `items`.
    ///
    /// Rebuilding the existing menu object (rather than swapping in a new one)
    /// lets the status item keep a single stable `NSMenu` and refresh its
    /// contents from `menuNeedsUpdate(_:)`.
    ///
    /// - Parameters:
    ///   - menu: The menu to clear and fill.
    ///   - items: Current items (already sorted by the store).
    ///   - now: Reference time for initial countdown rendering.
    ///   - actions: Closures invoked by the menu commands.
    /// - Returns: The dynamic row views keyed by item id, for in-place refresh.
    @discardableResult
    func populate(_ menu: NSMenu, items: [TimerItem], now: Date, actions: Actions) -> [TimerItem.ID: TimerRowView] {
        menu.removeAllItems()
        menu.autoenablesItems = false

        menu.addItem(BlockMenuItem(title: "Add Timer…", keyEquivalent: "t", handler: actions.addTimer))
        menu.addItem(BlockMenuItem(title: "Add Alarm…", keyEquivalent: "a", handler: actions.addAlarm))
        menu.addItem(BlockMenuItem(title: "Add Stopwatch…", keyEquivalent: "s", handler: actions.addStopwatch))
        menu.addItem(.separator())

        let rows = appendDynamicSection(to: menu, items: items, now: now, delete: actions.delete, togglePause: actions.togglePause)

        menu.addItem(.separator())
        menu.addItem(BlockMenuItem(title: "About Menu Timer", handler: actions.about))
        menu.addItem(BlockMenuItem(title: "Quit Menu Timer", keyEquivalent: "q", handler: actions.quit))

        return rows
    }

    // MARK: - Dynamic section

    private func appendDynamicSection(
        to menu: NSMenu,
        items: [TimerItem],
        now: Date,
        delete: @escaping (TimerItem.ID) -> Void,
        togglePause: @escaping (TimerItem.ID) -> Void
    ) -> [TimerItem.ID: TimerRowView] {
        guard !items.isEmpty else {
            let empty = NSMenuItem(title: "No active timers, alarms, or stopwatches", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return [:]
        }

        var rows: [TimerItem.ID: TimerRowView] = [:]
        for item in items {
            let rowView = TimerRowView(item: item, now: now)
            rowView.onDelete = { delete(item.id) }
            if item.kind == .stopwatch {
                rowView.onTogglePause = { togglePause(item.id) }
            }

            let menuItem = NSMenuItem()
            menuItem.view = rowView
            menu.addItem(menuItem)

            rows[item.id] = rowView
        }
        return rows
    }
}