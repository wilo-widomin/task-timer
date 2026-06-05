//
//  AppDelegate.swift
//  MenuTimer
//
//  Wires together the store, status-item menu and 1 Hz tick engine. Form and
//  About presentation, notification authorization and drift correction are
//  layered in during later phases.
//

import AppKit

/// Application delegate for the MenuTimer agent app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var store: TimerStore!
    private var statusController: StatusItemController!
    private var tickEngine: TickEngine!
    private let notificationService = NotificationService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let persistence = JSONPersistenceService()
        store = TimerStore(persistence: persistence, notificationService: notificationService)

        // Load the persisted store synchronously to avoid an empty-menu flash,
        // then reconcile any items that fired while the app was not running.
        store.adoptInitialState(persistence.loadSynchronously())
        store.reconcile(now: Date())

        statusController = StatusItemController(
            store: store,
            onAddTimer: { [weak self] in self?.presentAddTimer() },
            onAddAlarm: { [weak self] in self?.presentAddAlarm() },
            onAbout: { [weak self] in self?.presentAbout() }
        )

        tickEngine = TickEngine { [weak self] now in
            guard let self else { return }
            self.store.tick(now: now)
            self.statusController.tick(now: now)
        }
        tickEngine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickEngine?.stop()
    }

    // MARK: - Presentation (filled in during Phase 4)

    private func presentAddTimer() {
        NSLog("MenuTimer: Add Timer (form arrives in Phase 4)")
    }

    private func presentAddAlarm() {
        NSLog("MenuTimer: Add Alarm (form arrives in Phase 4)")
    }

    private func presentAbout() {
        NSLog("MenuTimer: About (window arrives in Phase 4)")
    }
}
