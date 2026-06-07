//
//  TimerStore.swift
//  MenuTimer
//
//  The single source of truth for all timers, alarms and stopwatches. A
//  lightweight MVVM view-model: an `ObservableObject` that owns the item list,
//  drives firing on each tick, and persists every mutation.
//

import Foundation
import Combine

/// Observable owner of all timers, alarms and stopwatches.
///
/// All access is `@MainActor`-isolated: mutations happen on the main thread and
/// persistence is dispatched asynchronously to the (background) persistence
/// actor. The published `items` array drives the menu's dynamic section.
@MainActor
public final class TimerStore: ObservableObject {

    /// All tracked items, ordered by soonest fire date first (timers/alarms)
    /// followed by stopwatches sorted by creation time.
    @Published public private(set) var items: [TimerItem] = []

    private let persistence: PersistenceService
    private let notificationService: NotificationServing
    private let scheduler: FireScheduler

    /// Creates a store.
    /// - Parameters:
    ///   - persistence: Backend used to load/save the item list.
    ///   - notificationService: Used to post notifications when items fire.
    ///   - scheduler: Pure firing-transition logic.
    public init(
        persistence: PersistenceService,
        notificationService: NotificationServing,
        scheduler: FireScheduler = FireScheduler()
    ) {
        self.persistence = persistence
        self.notificationService = notificationService
        self.scheduler = scheduler
    }

    // MARK: - Loading & reconciliation

    /// Adopts an already-loaded persisted state without persisting it back.
    ///
    /// Used at launch with a synchronous bootstrap read to populate the menu
    /// immediately. Follow with `reconcile(now:)` to fire any missed items.
    /// - Parameter store: The persisted state to adopt.
    public func adoptInitialState(_ store: PersistedStore) {
        items = sorted(store.items)
    }

    /// Loads persisted items and reconciles them against the current time.
    ///
    /// Any item that fired while the app was not running is transitioned and
    /// (if not already notified) reported. Call once at launch.
    /// - Parameter now: Reference time, injectable for testing.
    public func load(now: Date = Date()) async {
        let store = await persistence.load()
        items = sorted(store.items)
        reconcile(now: now)
    }

    /// Re-evaluates all items against `now`, firing any that are due.
    ///
    /// Equivalent to a single tick; used both at launch and on app activation
    /// to correct for timer drift or system sleep.
    /// - Parameter now: Reference time.
    public func reconcile(now: Date = Date()) {
        tick(now: now)
    }

    // MARK: - Mutations

    /// Adds a countdown timer and persists.
    /// - Returns: The newly created item.
    @discardableResult
    public func addTimer(title: String, duration: TimeInterval, now: Date = Date()) -> TimerItem {
        let item = TimerItem.timer(title: title, duration: duration, now: now)
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Adds a repeating countdown timer (e.g. pomodoro) and persists.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - duration: Seconds per cycle.
    ///   - repeatInterval: Seconds between repeats (typically same as duration).
    ///   - cycles: Total firings (nil = infinite).
    /// - Returns: The newly created item.
    @discardableResult
    public func addRepeatingTimer(
        title: String,
        duration: TimeInterval,
        repeatInterval: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        let item = TimerItem.repeatingTimer(
            title: title,
            duration: duration,
            repeatInterval: repeatInterval,
            cycles: cycles,
            now: now
        )
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Adds an absolute-time alarm and persists.
    /// - Returns: The newly created item.
    @discardableResult
    public func addAlarm(title: String, fireDate: Date, now: Date = Date()) -> TimerItem {
        let item = TimerItem.alarm(title: title, fireDate: fireDate, now: now)
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Adds a repeating (snoozing) alarm and persists.
    @discardableResult
    public func addRepeatingAlarm(
        title: String,
        fireDate: Date,
        snoozeInterval: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        let item = TimerItem.repeatingAlarm(
            title: title,
            fireDate: fireDate,
            snoozeInterval: snoozeInterval,
            cycles: cycles,
            now: now
        )
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Adds a running stopwatch and persists.
    /// - Returns: The newly created item.
    @discardableResult
    public func addStopwatch(title: String, now: Date = Date()) -> TimerItem {
        let item = TimerItem.stopwatch(title: title, now: now)
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Adds a pomodoro timer and persists.
    @discardableResult
    public func addPomodoro(
        title: String,
        workDuration: TimeInterval,
        breakDuration: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        let item = TimerItem.pomodoro(
            title: title,
            workDuration: workDuration,
            breakDuration: breakDuration,
            cycles: cycles,
            now: now
        )
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Pauses a running stopwatch, capturing accumulated elapsed time.
    /// No-op if the item is not a running stopwatch.
    public func pauseStopwatch(id: TimerItem.ID, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].kind == .stopwatch,
              items[index].state == .running,
              let started = items[index].lastStartedDate else { return }

        items[index].accumulatedElapsed += now.timeIntervalSince(started)
        items[index].lastStartedDate = nil
        items[index].state = .paused
        persist()
    }

    /// Resumes a paused stopwatch.
    /// No-op if the item is not a paused stopwatch.
    public func continueStopwatch(id: TimerItem.ID, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].kind == .stopwatch,
              items[index].state == .paused else { return }

        items[index].lastStartedDate = now
        items[index].state = .running
        persist()
    }

    // MARK: - Updates

    /// Updates the title of any item (used by stopwatch editing).
    public func updateItemTitle(id: TimerItem.ID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              !title.isEmpty else { return }
        items[index].title = title
        persist()
    }

    /// Fully updates a timer: title, duration, repeat settings.
    /// Recalculates `fireDate` from `now`.
    public func updateTimer(
        id: TimerItem.ID,
        title: String,
        duration: TimeInterval,
        repeatInterval: TimeInterval?,
        remainingCycles: Int?,
        now: Date = Date()
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].kind == .timer,
              duration > 0 else { return }

        items[index].title = title
        items[index].configuredDuration = duration
        items[index].fireDate = now.addingTimeInterval(duration)
        items[index].repeatInterval = repeatInterval
        items[index].remainingCycles = remainingCycles
        items[index].state = .running
        items[index].didNotify = false
        items = sorted(items)
        persist()
    }

    /// Fully updates an alarm: title, fire date, snooze settings.
    public func updateAlarm(
        id: TimerItem.ID,
        title: String,
        fireDate: Date,
        repeatInterval: TimeInterval?,
        remainingCycles: Int?,
        now: Date = Date()
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].kind == .alarm else { return }

        items[index].title = title
        items[index].fireDate = fireDate
        items[index].repeatInterval = repeatInterval
        items[index].remainingCycles = remainingCycles
        items[index].state = .running
        items[index].didNotify = false
        items = sorted(items)
        persist()
    }

    /// Fully updates a pomodoro: title, work/break durations, cycles.
    /// If currently in work phase, recalculates `fireDate` from `now`.
    public func updatePomodoro(
        id: TimerItem.ID,
        title: String,
        workDuration: TimeInterval,
        breakDuration: TimeInterval,
        remainingCycles: Int?,
        now: Date = Date()
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].kind == .pomodoro else { return }

        items[index].title = title
        items[index].configuredDuration = workDuration
        items[index].breakDuration = breakDuration
        items[index].remainingCycles = remainingCycles

        // If in work phase, reset the countdown from now.
        if !items[index].isBreakPhase {
            items[index].fireDate = now.addingTimeInterval(workDuration)
        }
        // If in break phase, leave the current fireDate alone (break is running).

        items[index].state = .running
        items[index].didNotify = false
        items = sorted(items)
        persist()
    }

    /// Removes the item with the given identifier and persists.
    public func remove(id: TimerItem.ID) {
        let before = items.count
        items.removeAll { $0.id == id }
        guard items.count != before else { return }
        persist()
    }

    /// Removes all finished items and persists. Useful for a "clear finished"
    /// affordance. Stopwatches (which never finish) are unaffected.
    public func clearFinished() {
        let before = items.count
        items.removeAll { $0.state == .finished }
        guard items.count != before else { return }
        persist()
    }

    // MARK: - Tick

    /// Advances the world to `now`: fires due items, posts notifications, and
    /// persists if anything changed.
    ///
    /// Called by `TickEngine` once per second. When nothing fires, this is a
    /// no-op that does not touch `@Published` state (the menu's per-second
    /// countdown refresh is handled separately by the menu refresher).
    /// - Parameter now: Reference time.
    public func tick(now: Date = Date()) {
        var working = items
        let fired = scheduler.process(items: &working, now: now)
        guard !fired.isEmpty else { return }

        items = sorted(working)
        for item in fired {
            notificationService.postNotification(for: item)
        }
        persist()
    }

    // MARK: - Helpers

    /// Sorts running items by soonest fire date first, with finished items
    /// last. Stopwatches are placed after timers/alarms, sorted by creation
    /// time (oldest first).
    private func sorted(_ items: [TimerItem]) -> [TimerItem] {
        items.sorted { lhs, rhs in
            // Group: running timers/alarms, then stopwatches, then finished
            let lhsGroup = sortGroup(lhs)
            let rhsGroup = sortGroup(rhs)
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

            // Within running timers/alarms: soonest fire date first
            if lhsGroup == 0 { return lhs.fireDate < rhs.fireDate }
            // Within pomodoros: work before break, then soonest fire
            if lhsGroup == 1 {
                let lk = pomodoroSortKey(lhs)
                let rk = pomodoroSortKey(rhs)
                if lk != rk { return lk < rk }
                return lhs.fireDate < rhs.fireDate
            }
            // Within finished: soonest fire date first
            return lhs.fireDate < rhs.fireDate
        }
    }

    /// Sort group:
    /// 0 = running timer/alarm
    /// 1 = pomodoro (any state)
    /// 2 = stopwatch (any state: running or paused)
    /// 3 = finished timer/alarm
    private func sortGroup(_ item: TimerItem) -> Int {
        if item.kind == .stopwatch { return 2 }
        if item.kind == .pomodoro { return 1 }
        if item.state == .finished { return 3 }
        return 0
    }

    /// Within pomodoros: work phase first, then break, then finished.
    private func pomodoroSortKey(_ item: TimerItem) -> Int {
        if item.state == .finished { return 2 }
        return item.isBreakPhase ? 1 : 0
    }

    /// Persists the current item list off the main thread. Failures are logged
    /// and swallowed — a transient write error must not crash the UI.
    private func persist() {
        let snapshot = PersistedStore(items: items)
        Task { [persistence] in
            do {
                try await persistence.save(snapshot)
            } catch {
                NSLog("MenuTimer: failed to persist store: \(error.localizedDescription)")
            }
        }
    }
}