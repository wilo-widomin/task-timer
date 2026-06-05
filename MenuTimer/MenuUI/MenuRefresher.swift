//
//  MenuRefresher.swift
//  MenuTimer
//
//  Updates the countdown labels of the currently visible menu rows without
//  rebuilding the menu. Driven by the 1 Hz tick while the menu is open.
//

import AppKit

/// Refreshes open-menu row countdowns in place.
@MainActor
struct MenuRefresher {

    /// Updates each row's labels to reflect the matching item at `now`.
    ///
    /// Rows whose item no longer exists are left untouched (the menu rebuilds on
    /// next open). This is intentionally cheap: only text values change.
    /// - Parameters:
    ///   - rows: The visible rows keyed by item id.
    ///   - items: The current items.
    ///   - now: Reference time.
    func refresh(rows: [TimerItem.ID: TimerRowView], items: [TimerItem], now: Date) {
        guard !rows.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for (id, row) in rows {
            guard let item = byID[id] else { continue }
            row.update(with: item, now: now)
        }
    }
}
