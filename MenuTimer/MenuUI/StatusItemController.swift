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
    private let onAbout: () -> Void

    private var visibleRows: [TimerItem.ID: TimerRowView] = [:]
    private var isMenuOpen = false

    /// Creates the controller and installs the status item.
    /// - Parameters:
    ///   - store: The shared timer store.
    ///   - onAddTimer: Presents the Add Timer form.
    ///   - onAddAlarm: Presents the Add Alarm form.
    ///   - onAbout: Presents the About window.
    init(
        store: TimerStore,
        onAddTimer: @escaping () -> Void,
        onAddAlarm: @escaping () -> Void,
        onAbout: @escaping () -> Void
    ) {
        self.store = store
        self.onAddTimer = onAddTimer
        self.onAddAlarm = onAddAlarm
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
            about: { [weak self] in self?.onAbout() },
            quit: { NSApp.terminate(nil) },
            delete: { [weak self] id in self?.store.remove(id: id) }
        )
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
