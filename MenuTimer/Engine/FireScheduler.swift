//
//  FireScheduler.swift
//  MenuTimer
//
//  Pure state-transition logic for firing. Given the current items and a
//  reference time, it transitions any running item that has reached its fire
//  date to `.finished` and flags it for notification — exactly once.
//
//  Keeping this logic free of UI and notification dependencies makes it
//  trivially testable and deterministic.
//

import Foundation

/// Detects fire-date crossings and transitions item state idempotently.
public struct FireScheduler: Sendable {

    public init() {}

    /// Processes all items against `now`, mutating those that have just fired.
    ///
    /// An item "newly fires" when it is `.running`, has reached its fire date,
    /// and has not yet been notified (`didNotify == false`). Such items are
    /// transitioned to `.finished` with `didNotify = true` and returned so the
    /// caller can post a notification. The `didNotify` flag guarantees a given
    /// firing is reported at most once, even across repeated ticks or relaunch.
    ///
    /// - Parameters:
    ///   - items: The items to process, mutated in place.
    ///   - now: The reference instant.
    /// - Returns: The items that newly fired during this call (may be empty).
    @discardableResult
    public func process(items: inout [TimerItem], now: Date) -> [TimerItem] {
        var fired: [TimerItem] = []
        for index in items.indices {
            // Stopwatches don't fire — they count up indefinitely.
            guard items[index].kind != .stopwatch else { continue }
            guard items[index].hasFired(at: now), !items[index].didNotify else { continue }
            items[index].state = .finished
            items[index].didNotify = true
            fired.append(items[index])
        }
        return fired
    }
}
