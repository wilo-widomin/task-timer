//
//  TimerItem.swift
//  MenuTimer
//
//  Core domain model. A `TimerItem` represents either a countdown timer or an
//  absolute-time alarm. The design principle is that the *fire date* is the
//  single source of truth: the remaining time is always derived from
//  `fireDate - now`, never stored. This keeps items correct across sleep,
//  reboots and wall-clock changes.
//

import Foundation

/// The kind of a scheduled item.
public enum ItemKind: String, Codable, Sendable {
    /// A countdown timer created from a duration (`fireDate = createdAt + duration`).
    case timer
    /// An alarm created from an absolute date/time (`fireDate` is that instant).
    case alarm
}

/// The lifecycle state of a scheduled item.
public enum ItemState: String, Codable, Sendable {
    /// The item is counting down towards its fire date.
    case running
    /// The item has reached its fire date and is no longer counting down.
    case finished
}

/// A single timer or alarm tracked by the app.
///
/// Instances are value types and `Codable`, forming the unit of persistence.
public struct TimerItem: Identifiable, Codable, Equatable, Sendable {
    /// Stable unique identity, also used as the notification request identifier.
    public let id: UUID
    /// Whether this is a countdown timer or an absolute alarm.
    public let kind: ItemKind
    /// User-facing description shown in the menu and notification.
    public var title: String
    /// When the item was created.
    public let createdAt: Date
    /// The absolute instant at which the item fires. Single source of truth.
    public var fireDate: Date
    /// Original configured duration in seconds. Present only for `.timer` items.
    public var configuredDuration: TimeInterval?
    /// Current lifecycle state.
    public var state: ItemState
    /// Whether a user notification has already been posted for this firing.
    /// Guarantees notifications are delivered exactly once (idempotency).
    public var didNotify: Bool

    /// Designated initializer.
    public init(
        id: UUID = UUID(),
        kind: ItemKind,
        title: String,
        createdAt: Date,
        fireDate: Date,
        configuredDuration: TimeInterval? = nil,
        state: ItemState = .running,
        didNotify: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.createdAt = createdAt
        self.fireDate = fireDate
        self.configuredDuration = configuredDuration
        self.state = state
        self.didNotify = didNotify
    }
}

// MARK: - Convenience factories

public extension TimerItem {
    /// Creates a running countdown timer.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - duration: Countdown length in seconds. Should be `> 0`.
    ///   - now: The creation instant (injectable for testing).
    static func timer(
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

    /// Creates a running alarm that fires at an absolute instant.
    /// - Parameters:
    ///   - title: User-facing description.
    ///   - fireDate: The absolute instant to fire at. Should be in the future.
    ///   - now: The creation instant (injectable for testing).
    static func alarm(
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
}

// MARK: - Derived time

public extension TimerItem {
    /// Seconds remaining until the fire date.
    ///
    /// Returns `0` for finished items. May be negative for a running item whose
    /// fire date is in the past but has not yet been reconciled by the scheduler.
    /// - Parameter now: The reference instant (defaults to `Date()`).
    func remaining(at now: Date = Date()) -> TimeInterval {
        guard state == .running else { return 0 }
        return fireDate.timeIntervalSince(now)
    }

    /// Whether a running item has reached (or passed) its fire date.
    /// - Parameter now: The reference instant (defaults to `Date()`).
    func hasFired(at now: Date = Date()) -> Bool {
        state == .running && remaining(at: now) <= 0
    }
}
