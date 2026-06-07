//
//  AppDelegate.swift
//  MenuTimer
//
//  Application lifecycle: bootstraps the store, status-item menu, forms and the
//  1 Hz tick engine; requests notification authorization; and reconciles item
//  state on launch, activation and wake-from-sleep to correct for timer drift.
//

import AppKit

/// Application delegate **and** programmatic entry point for the MenuTimer
/// agent app.
///
/// We drive the `NSApplication` lifecycle ourselves (rather than relying on
/// `NSApplicationMain` / a storyboard) because MenuTimer is a menu-bar agent
/// with no Dock icon and no main window. Using `@main` with a static `main()`
/// keeps that explicit control while giving the entry point a `@MainActor`
/// context, so constructing this `@MainActor`-isolated delegate is legal under
/// Swift concurrency checking.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate

        // Reinforce LSUIElement=YES at runtime: run as an accessory (menu-bar)
        // app with no Dock presence and no application menu in the menu bar.
        application.setActivationPolicy(.accessory)

        application.run()
    }

    private var store: TimerStore!
    private var statusController: StatusItemController!
    private var tickEngine: TickEngine!
    private var windowPresenter: WindowPresenter!
    private let notificationService = NotificationService()

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        let persistence = JSONPersistenceService()
        store = TimerStore(persistence: persistence, notificationService: notificationService)

        // Synchronous bootstrap load avoids an empty-menu flash; reconcile then
        // fires anything that elapsed while the app was not running.
        store.adoptInitialState(persistence.loadSynchronously())
        store.reconcile(now: Date())

        windowPresenter = WindowPresenter(store: store)

        statusController = StatusItemController(
            store: store,
            onAddTimer: { [weak self] in self?.windowPresenter.showAddTimer() },
            onAddAlarm: { [weak self] in self?.windowPresenter.showAddAlarm() },
            onAddStopwatch: { [weak self] in self?.windowPresenter.showAddStopwatch() },
            onAddPomodoro: { [weak self] in self?.windowPresenter.showAddPomodoro() },
            onAbout: { [weak self] in self?.windowPresenter.showAbout() }
        )

        tickEngine = TickEngine { [weak self] now in
            guard let self else { return }
            self.store.tick(now: now)
            self.statusController.tick(now: now)
        }
        tickEngine.start()

        observeWakeFromSleep()

        // Request notification permission without blocking launch.
        Task { await notificationService.requestAuthorization() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickEngine?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    /// Opt in to secure state restoration (silences the macOS 14+ warning).
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Drift correction

    func applicationDidBecomeActive(_ notification: Notification) {
        // The app may have been inactive long enough for items to elapse;
        // reconcile against the real clock rather than trusting tick cadence.
        store?.reconcile(now: Date())
    }

    private func observeWakeFromSleep() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        // Timers do not fire while the machine is asleep; catch up on wake.
        store?.reconcile(now: Date())
    }
}
