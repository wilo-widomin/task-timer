//
//  FireScheduler.swift
//  MenuTimer
//
//  Pure state-transition logic for firing. Given the current items and a
//  reference time, it transitions any running item that has reached its fire
//  date to `.finished` and flags it for notification — exactly once.
//
//  Repeating items (with `repeatInterval` set) are reset instead of finished:
//  their fireDate is advanced by repeatInterval and they keep running.
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
    /// and has not yet been notified (`didNotify == false`). Such items are:
    ///
    /// - **Non-repeating**: transitioned to `.finished` with `didNotify = true`.
    /// - **Repeating** (has `repeatInterval`): fireDate advanced by
    ///   `repeatInterval`, `remainingCycles` decremented (if finite), and
    ///   `didNotify` reset to `false` for the next cycle. On the last cycle
    ///   the item transitions to `.finished` like a non-repeating item.
    ///
    /// The `didNotify` flag guarantees a given firing is reported at most
    /// once, even across repeated ticks or relaunch.
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

            if items[index].kind == .pomodoro {
                // Pomodoro: alternate between work and break phases.
                let snapshot = items[index]
                items[index].didNotify = true
                fired.append(snapshot)

                if items[index].isBreakPhase {
                    // Break just ended → back to work (or finish).
                    if let cycles = items[index].remainingCycles {
                        if cycles <= 1 {
                            // Last work cycle completed after this break.
                            items[index].state = .finished
                            continue
                        }
                        items[index].remainingCycles = cycles - 1
                    }
                    items[index].isBreakPhase = false
                    items[index].fireDate = now.addingTimeInterval(items[index].configuredDuration ?? 1500)
                    items[index].didNotify = false
                } else {
                    // Work just ended → switch to break.
                    items[index].isBreakPhase = true
                    items[index].fireDate = now.addingTimeInterval(items[index].breakDuration)
                    items[index].didNotify = false
                }
            } else if items[index].isRepeating {
                // Repeating item: snapshot, notify, then reset or finish.
                let snapshot = items[index]
                items[index].didNotify = true  // prevent double-fire this tick
                fired.append(snapshot)

                if let cycles = items[index].remainingCycles {
                    if cycles <= 1 {
                        // Last cycle — finish.
                        items[index].state = .finished
                        continue
                    }
                    items[index].remainingCycles = cycles - 1
                }
                // Infinite or more remain: reset fireDate for next cycle.
                items[index].fireDate = now.addingTimeInterval(items[index].repeatInterval!)
                items[index].didNotify = false
            } else {
                // Non-repeating: finish normally.
                items[index].state = .finished
                items[index].didNotify = true
                fired.append(items[index])
            }
        }
        return fired
    }
}