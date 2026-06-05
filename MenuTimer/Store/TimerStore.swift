//
//  TimerStore.swift
//  MenuTimer
//
//  The single source of truth for all timers and alarms. A lightweight MVVM
//  view-model: an `ObservableObject` that owns the item list, drives firing on
//  each tick, and persists every mutation.
//

import Foundation
import Combine

/// Observable owner of all timers and alarms.
///
/// All access is `@MainActor`-isolated: mutations happen on the main thread and
/// persistence is dispatched asynchronously to the (background) persistence
/// actor. The published `items` array drives the menu's dynamic section.
@MainActor
public final class TimerStore: ObservableObject {

    /// All tracked items, ordered by soonest fire date first.
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

    /// Adds an absolute-time alarm and persists.
    /// - Returns: The newly created item.
    @discardableResult
    public func addAlarm(title: String, fireDate: Date, now: Date = Date()) -> TimerItem {
        let item = TimerItem.alarm(title: title, fireDate: fireDate, now: now)
        items = sorted(items + [item])
        persist()
        return item
    }

    /// Removes the item with the given identifier and persists.
    public func remove(id: TimerItem.ID) {
        let before = items.count
        items.removeAll { $0.id == id }
        guard items.count != before else { return }
        persist()
    }

    /// Removes all finished items and persists. Useful for a "clear finished"
    /// affordance.
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

    /// Sorts running items by soonest fire date, with finished items last.
    private func sorted(_ items: [TimerItem]) -> [TimerItem] {
        items.sorted { lhs, rhs in
            if lhs.state != rhs.state {
                return lhs.state == .running   // running before finished
            }
            return lhs.fireDate < rhs.fireDate
        }
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
