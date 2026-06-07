//
//  StatusItemController.swift
//  MenuTimer
//
//  Owns the NSStatusItem and its menu. Rebuilds the menu on open, refreshes the
//  visible countdowns each tick, and routes commands to the store and the
//  injected presentation closures.
//

import AppKit

/// Manages the menu-bar status item and its menu lifecycle.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let store: TimerStore
    private let builder = MenuBuilder()
    private let refresher = MenuRefresher()

    /// Presentation hooks owned by the app delegate (window controllers).
    private let onAddTimer: () -> Void
    private let onAddAlarm: () -> Void
    private let onAddStopwatch: () -> Void
    private let onAbout: () -> Void

    private var visibleRows: [TimerItem.ID: TimerRowView] = [:]
    private var isMenuOpen = false

    /// Creates the controller and installs the status item.
    /// - Parameters:
    ///   - store: The shared timer store.
    ///   - onAddTimer: Presents the Add Timer form.
    ///   - onAddAlarm: Presents the Add Alarm form.
    ///   - onAddStopwatch: Presents the Add Stopwatch form.
    ///   - onAbout: Presents the About window.
    init(
        store: TimerStore,
        onAddTimer: @escaping () -> Void,
        onAddAlarm: @escaping () -> Void,
        onAddStopwatch: @escaping () -> Void,
        onAbout: @escaping () -> Void
    ) {
        self.store = store
        self.onAddTimer = onAddTimer
        self.onAddAlarm = onAddAlarm
        self.onAddStopwatch = onAddStopwatch
        self.onAbout = onAbout
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Status button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // Prefer the bundled menu-bar glyph; fall back to the SF Symbol if the
        // asset is ever unavailable.
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "timer", accessibilityDescription: "Menu Timer")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
    }

    // MARK: - Tick

    /// Called once per second by the tick engine, after the store has ticked.
    /// Refreshes the visible row countdowns while the menu is open.
    func tick(now: Date) {
        guard isMenuOpen else { return }
        refresher.refresh(rows: visibleRows, items: store.items, now: now)
    }

    // MARK: - Menu actions

    private func makeActions() -> MenuBuilder.Actions {
        MenuBuilder.Actions(
            addTimer: { [weak self] in self?.onAddTimer() },
            addAlarm: { [weak self] in self?.onAddAlarm() },
            addStopwatch: { [weak self] in self?.onAddStopwatch() },
            about: { [weak self] in self?.onAbout() },
            quit: { NSApp.terminate(nil) },
            delete: { [weak self] id in self?.confirmDelete(id: id) },
            togglePause: { [weak self] id in self?.togglePauseStopwatch(id: id) }
        )
    }

    /// Asks the user to confirm removing an item, then removes it.
    ///
    /// A modal `NSAlert` is shown for **running** items (trash icon). Finished
    /// items (checkmark icon) and stopwatches are removed immediately without
    /// confirmation.
    private func confirmDelete(id: TimerItem.ID) {
        guard let item = store.items.first(where: { $0.id == id }) else { return }

        // Close the menu before touching it. The row's button fires on
        // mouse-*down* while the menu is still tracking, so the matching
        // mouse-up is still pending. If we mutate the menu (removing the row)
        // or run a modal in-place, that stray mouse-up lands on whatever menu
        // item has now shifted under the cursor — typically "About Menu Timer"
        // — and triggers it. Cancelling tracking and deferring the work to the
        // next run-loop turn lets the menu fully close first.
        menu.cancelTrackingWithoutAnimation()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Finished items (checkmark) and stopwatches skip confirmation.
            if item.state == .running && item.kind != .stopwatch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Delete \(item.title)?"
                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")

                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }

            self.store.remove(id: id)
        }
    }

    /// Toggles a stopwatch between paused and running states.
    private func togglePauseStopwatch(id: TimerItem.ID) {
        guard let item = store.items.first(where: { $0.id == id }) else { return }

        let now = Date()
        if item.state == .running {
            store.pauseStopwatch(id: id, now: now)
        } else if item.state == .paused {
            store.continueStopwatch(id: id, now: now)
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        visibleRows = builder.populate(menu, items: store.items, now: Date(), actions: makeActions())
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        visibleRows = [:]
    }
}