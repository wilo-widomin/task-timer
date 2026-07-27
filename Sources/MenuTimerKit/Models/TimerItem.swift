//
//  TimerItem.swift
//  MenuTimer
//
//  Core domain model. A `TimerItem` represents either a countdown timer, an
//  absolute-time alarm, or a stopwatch that counts elapsed time. The design
//  principle for timers and alarms is that the *fire date* is the single source
//  of truth: the remaining time is derived from `fireDate - now`, never stored.
//  For stopwatches, elapsed time is derived from `lastStartedDate` +
//  `accumulatedElapsed` to survive pauses.
//
//  Repeating timers/alarms: when `repeatInterval` is set, the item resets its
//  fireDate after firing and keeps running. `remainingCycles` tracks how many
//  more times it should fire (nil = infinite).
//

import Foundation

/// The kind of a scheduled item.
public enum ItemKind: String, Codable, Sendable {
    /// A countdown timer created from a duration (`fireDate = createdAt + duration`).
    public case timer
    /// An alarm created from an absolute date/time (`fireDate` is that instant).
    public case alarm
    /// A stopwatch that counts elapsed time. Can be paused and resumed.
    public case stopwatch
    /// A pomodoro timer that alternates between work and break phases.
    public case pomodoro
}

/// The lifecycle state of a scheduled item.
public enum ItemState: String, Codable, Sendable {
    /// The item is counting down (or counting up for stopwatches).
    public case running
    /// The item is paused (stopwatch only).
    public case paused
    /// The item has reached its fire date and is no longer counting down.
    public case finished
}

/// A single timer, alarm, or stopwatch tracked by the app.
///
/// Instances are value types and `Codable`, forming the unit of persistence.
public struct TimerItem: Identifiable, Codable, Equatable, Sendable {
    /// Stable unique identity, also used as the notification request identifier.
    public let id: UUID
    /// Whether this is a countdown timer, absolute alarm, or stopwatch.
    public let kind: ItemKind
    /// User-facing description shown in the menu and notification.
    public var title: String
    /// When the item was created.
    public let createdAt: Date
    /// The absolute instant at which the item fires. Single source of truth for
    /// timers and alarms. Not used for stopwatches.
    public var fireDate: Date
    /// Original configured duration in seconds. Present only for `.timer` items.
    public var configuredDuration: TimeInterval?
    /// Current lifecycle state.
    public var state: ItemState
    /// Whether a user notification has already been posted for this firing.
    /// Guarantees notifications are delivered exactly once (idempotency).
    public var didNotify: Bool
    /// Accumulated elapsed seconds across pause/resume cycles (stopwatch only).
    /// Set when pausing: `accumulatedElapsed += now - lastStartedDate`.
    public var accumulatedElapsed: TimeInterval
    /// When the stopwatch was last started or resumed. `nil` when paused.
    /// Used to derive current elapsed without updating on every tick.
    public var lastStartedDate: Date?
    /// If set, this item repeats every N seconds after firing instead of
    /// finishing. Works for both timers and alarms (snooze behaviour).
    /// - `nil`: no repeat (current default behaviour).
    /// - non-nil: repeat every `repeatInterval` seconds.
    public var repeatInterval: TimeInterval?
    /// How many more firing cycles remain. Decremented each time the item
    /// fires and resets. The item finishes when this reaches 0.
    /// - `nil`: infinite repeats.
    /// - `N`: will fire N more times (including the current one).
    public var remainingCycles: Int?

    /// Duration of the break phase in seconds (pomodoro only).
    /// Used by `.pomodoro` items to alternate between work (`configuredDuration`)
    /// and break.
    public var breakDuration: TimeInterval
    /// Whether a `.pomodoro` item is currently in its break phase.
    /// When `false` the item is in its work phase.
    public var isBreakPhase: Bool

    /// Whether this item repeats after firing (non-nil interval and not finished).
    public var isRepeating: Bool {
        repeatInterval != nil && repeatInterval! > 0
    }

    /// Whether this item repeats infinitely.
    public var isInfinite: Bool {
        isRepeating && remainingCycles == nil
    }

    /// User-friendly label for the repeat configuration, e.g. "×4", "∞", "".
    public var repeatLabel: String {
        guard isRepeating else { return "" }
        if remainingCycles == nil { return "∞" }
        if let cycles = remainingCycles, cycles > 0 { return "×\(cycles)" }
        return ""
    }

    /// Designated initializer.
    public init(
        id: UUID = UUID(),
        kind: ItemKind,
        title: String,
        createdAt: Date,
        fireDate: Date,
        configuredDuration: TimeInterval? = nil,
        state: ItemState = .running,
        didNotify: Bool = false,
        accumulatedElapsed: TimeInterval = 0,
        lastStartedDate: Date? = nil,
        repeatInterval: TimeInterval? = nil,
        remainingCycles: Int? = nil,
        breakDuration: TimeInterval = 0,
        isBreakPhase: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.createdAt = createdAt
        self.fireDate = fireDate
        self.configuredDuration = configuredDuration
        self.state = state
        self.didNotify = didNotify
        self.accumulatedElapsed = accumulatedElapsed
        self.lastStartedDate = lastStartedDate
        self.repeatInterval = repeatInterval
        self.remainingCycles = remainingCycles
        self.breakDuration = breakDuration
        self.isBreakPhase = isBreakPhase
    }
}

// MARK: - Codable (backward-compatible with schema v1 & v2)

extension TimerItem {
    private enum CodingKeys: String, CodingKey {
        public case id, kind, title, createdAt, fireDate, configuredDuration,
             state, didNotify, accumulatedElapsed, lastStartedDate,
             repeatInterval, remainingCycles, breakDuration, isBreakPhase
    }

    public init(from decoder: Decoder) throws {
        public let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ItemKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        fireDate = try container.decode(Date.self, forKey: .fireDate)
        configuredDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .configuredDuration)
        state = try container.decode(ItemState.self, forKey: .state)
        didNotify = try container.decode(Bool.self, forKey: .didNotify)
        // Schema v2 fields: default to 0/nil when absent (old data).
        accumulatedElapsed = try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedElapsed) ?? 0
        lastStartedDate = try container.decodeIfPresent(Date.self, forKey: .lastStartedDate)
        // Schema v3 fields: default to nil when absent.
        repeatInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .repeatInterval)
        remainingCycles = try container.decodeIfPresent(Int.self, forKey: .remainingCycles)
        // Schema v4 fields: default to 0/false when absent.
        breakDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .breakDuration) ?? 0
        isBreakPhase = try container.decodeIfPresent(Bool.self, forKey: .isBreakPhase) ?? false
    }
}

// MARK: - Convenience factories

public extension TimerItem {
    /// Creates a running countdown timer.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - duration: Countdown length in seconds. Should be `> 0`.
    ///   - now: The creation instant (injectable for testing).
    public static func timer(
        title: String,
        duration: TimeInterval,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .timer,
            title: title,
            createdAt: now,
            fireDate: now.addingTimeInterval(duration),
            configuredDuration: duration,
            state: .running,
            didNotify: false
        )
    }

    /// Creates a running repeating timer (e.g. pomodoro).
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - duration: Countdown length in seconds per cycle.
    ///   - repeatInterval: Seconds between repeats (same as duration typically).
    ///   - cycles: Total number of firings. `nil` = infinite, `>= 1`.
    ///   - now: The creation instant (injectable for testing).
    public static func repeatingTimer(
        title: String,
        duration: TimeInterval,
        repeatInterval: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .timer,
            title: title,
            createdAt: now,
            fireDate: now.addingTimeInterval(duration),
            configuredDuration: duration,
            state: .running,
            didNotify: false,
            repeatInterval: repeatInterval,
            remainingCycles: cycles
        )
    }

    /// Creates a running alarm that fires at an absolute instant.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - fireDate: The absolute instant to fire at. Should be in the future.
    ///   - now: The creation instant (injectable for testing).
    public static func alarm(
        title: String,
        fireDate: Date,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .alarm,
            title: title,
            createdAt: now,
            fireDate: fireDate,
            configuredDuration: nil,
            state: .running,
            didNotify: false
        )
    }

    /// Creates a snoozing alarm that repeats every `snoozeInterval` seconds.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - fireDate: First fire instant.
    ///   - snoozeInterval: Seconds between snooze repeats.
    ///   - cycles: Total number of firings. `nil` = infinite, `>= 1`.
    ///   - now: The creation instant (injectable for testing).
    public static func repeatingAlarm(
        title: String,
        fireDate: Date,
        snoozeInterval: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .alarm,
            title: title,
            createdAt: now,
            fireDate: fireDate,
            configuredDuration: nil,
            state: .running,
            didNotify: false,
            repeatInterval: snoozeInterval,
            remainingCycles: cycles
        )
    }

    /// Creates a pomodoro timer that alternates between work and break.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - workDuration: Work phase length in seconds.
    ///   - breakDuration: Break phase length in seconds.
    ///   - cycles: Number of work cycles (each = work + break). `nil` = infinite.
    ///   - now: The creation instant (injectable for testing).
    public static func pomodoro(
        title: String,
        workDuration: TimeInterval,
        breakDuration: TimeInterval,
        cycles: Int?,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .pomodoro,
            title: title,
            createdAt: now,
            fireDate: now.addingTimeInterval(workDuration),
            configuredDuration: workDuration,
            state: .running,
            didNotify: false,
            remainingCycles: cycles,
            breakDuration: breakDuration,
            isBreakPhase: false
        )
    }

    /// Creates a running stopwatch with zero elapsed time.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - now: The creation instant (injectable for testing).
    public static func stopwatch(
        title: String,
        now: Date = Date()
    ) -> TimerItem {
        TimerItem(
            kind: .stopwatch,
            title: title,
            createdAt: now,
            fireDate: now,
            configuredDuration: nil,
            state: .running,
            didNotify: false,
            accumulatedElapsed: 0,
            lastStartedDate: now
        )
    }
}

// MARK: - Derived time

public extension TimerItem {
    /// Seconds remaining until the fire date.
    ///
    /// Returns `0` for finished items and stopwatches. May be negative for a
    /// running item whose fire date is in the past but has not yet been
    /// reconciled by the scheduler.
    /// - Parameter now: The reference instant (defaults to `Date()`).
    public func remaining(at now: Date = Date()) -> TimeInterval {
        guard state == .running, kind != .stopwatch else { return 0 }
        return fireDate.timeIntervalSince(now)
    }

    /// Whether a running item has reached (or passed) its fire date.
    /// Stopwatches never fire — they always return `false`.
    /// - Parameter now: The reference instant (defaults to `Date()`).
    public func hasFired(at now: Date = Date()) -> Bool {
        guard kind != .stopwatch else { return false }
        return state == .running && remaining(at: now) <= 0
    }

    /// Elapsed seconds for stopwatches.
    ///
    /// When running: `accumulatedElapsed + time since lastStartedDate`.
    /// When paused/finished: `accumulatedElapsed`.
    /// Returns `0` for non-stopwatch items.
    /// - Parameter now: The reference instant (defaults to `Date()`).
    public func elapsed(at now: Date = Date()) -> TimeInterval {
        guard kind == .stopwatch else { return 0 }
        if state == .running, let started = lastStartedDate {
            return accumulatedElapsed + now.timeIntervalSince(started)
        }
        return accumulatedElapsed
    }
}