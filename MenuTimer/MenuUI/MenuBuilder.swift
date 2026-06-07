//
//  MenuBuilder.swift
//  MenuTimer
//
//  Builds the status-item menu: fixed commands plus a dynamic section of one
//  custom row per active item, grouped by kind (Timers, Alarms, Stopwatches).
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
        let addPomodoro: () -> Void
        let about: () -> Void
        let quit: () -> Void
        let delete: (TimerItem.ID) -> Void
        let togglePause: (TimerItem.ID) -> Void
        let edit: (TimerItem.ID) -> Void
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

        // ── Commands ──────────────────────────────────────────────
        menu.addItem(BlockMenuItem(title: "Add Timer…", keyEquivalent: "t", handler: actions.addTimer))
        menu.addItem(BlockMenuItem(title: "Add Alarm…", keyEquivalent: "a", handler: actions.addAlarm))
        menu.addItem(BlockMenuItem(title: "Add Pomodoro…", keyEquivalent: "p", handler: actions.addPomodoro))
        menu.addItem(BlockMenuItem(title: "Add Stopwatch…", keyEquivalent: "s", handler: actions.addStopwatch))
        menu.addItem(.separator())

        // ── Dynamic sections ──────────────────────────────────────
        let rows = appendGroupedSections(to: menu, items: items, now: now, delete: actions.delete, togglePause: actions.togglePause, edit: actions.edit)

        // ── Footer ────────────────────────────────────────────────
        menu.addItem(.separator())
        menu.addItem(BlockMenuItem(title: "About Menu Timer", handler: actions.about))
        menu.addItem(BlockMenuItem(title: "Quit Menu Timer", keyEquivalent: "q", handler: actions.quit))

        return rows
    }

    // MARK: - Grouped sections

    private func appendGroupedSections(
        to menu: NSMenu,
        items: [TimerItem],
        now: Date,
        delete: @escaping (TimerItem.ID) -> Void,
        togglePause: @escaping (TimerItem.ID) -> Void,
        edit: @escaping (TimerItem.ID) -> Void
    ) -> [TimerItem.ID: TimerRowView] {
        guard !items.isEmpty else {
            let empty = NSMenuItem(title: "No active timers, alarms, or stopwatches", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return [:]
        }

        let timers = items.filter { $0.kind == .timer }
        let alarms = items.filter { $0.kind == .alarm }
        let pomodoros = items.filter { $0.kind == .pomodoro }
        let stopwatches = items.filter { $0.kind == .stopwatch }

        var rows: [TimerItem.ID: TimerRowView] = [:]
        var hasPreviousSection = false

        if !timers.isEmpty {
            appendSeparatorIfNeeded(to: menu, hasPrevious: &hasPreviousSection)
            appendSectionHeader(to: menu, title: "Timers")
            appendRows(to: menu, items: timers, now: now, delete: delete, togglePause: togglePause, edit: edit, rows: &rows)
        }

        if !alarms.isEmpty {
            appendSeparatorIfNeeded(to: menu, hasPrevious: &hasPreviousSection)
            appendSectionHeader(to: menu, title: "Alarms")
            appendRows(to: menu, items: alarms, now: now, delete: delete, togglePause: togglePause, edit: edit, rows: &rows)
        }

        if !pomodoros.isEmpty {
            appendSeparatorIfNeeded(to: menu, hasPrevious: &hasPreviousSection)
            appendSectionHeader(to: menu, title: "Pomodoros")
            appendRows(to: menu, items: pomodoros, now: now, delete: delete, togglePause: togglePause, edit: edit, rows: &rows)
        }

        if !stopwatches.isEmpty {
            appendSeparatorIfNeeded(to: menu, hasPrevious: &hasPreviousSection)
            appendSectionHeader(to: menu, title: "Stopwatches")
            appendRows(to: menu, items: stopwatches, now: now, delete: delete, togglePause: togglePause, edit: edit, rows: &rows)
        }

        return rows
    }

    /// Adds a thin separator line before a section if there's already a
    /// previous section above it.
    private func appendSeparatorIfNeeded(to menu: NSMenu, hasPrevious: inout Bool) {
        if hasPrevious {
            menu.addItem(.separator())
        }
        hasPrevious = true
    }

    /// Adds a disabled section label with dark chalk-blue text.
    private func appendSectionHeader(to menu: NSMenu, title: String) {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize + 2, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.2, blue: 0.549, alpha: 1.0),
        ]
        item.attributedTitle = NSAttributedString(string: "  \(title)  ", attributes: attributes)
        menu.addItem(item)
    }

    private func appendRows(
        to menu: NSMenu,
        items: [TimerItem],
        now: Date,
        delete: @escaping (TimerItem.ID) -> Void,
        togglePause: @escaping (TimerItem.ID) -> Void,
        edit: @escaping (TimerItem.ID) -> Void,
        rows: inout [TimerItem.ID: TimerRowView]
    ) {
        for item in items {
            let rowView = TimerRowView(item: item, now: now)
            rowView.onDelete = { delete(item.id) }
            rowView.onEdit = { edit(item.id) }
            if item.kind == .stopwatch {
                rowView.onTogglePause = { togglePause(item.id) }
            }

            let menuItem = NSMenuItem()
            menuItem.view = rowView
            menu.addItem(menuItem)

            rows[item.id] = rowView
        }
    }
}