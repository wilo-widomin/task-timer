//
//  PersistedStore.swift
//  MenuTimer
//
//  The on-disk representation of the app's state. A small wrapper around the
//  list of items plus a schema version to enable forward migrations.
//

import Foundation

/// The serializable root object written to `store.json`.
public struct PersistedStore: Codable, Equatable, Sendable {
    /// The schema version of the persisted file, used to drive migrations.
    public var schemaVersion: Int
    /// All tracked timers, alarms and stopwatches.
    public var items: [TimerItem]

    /// The schema version produced by the current build.
    /// Version 2: added `accumulatedElapsed` and `lastStartedDate` fields for
    /// stopwatches.
    /// Version 3: added `repeatInterval` and `remainingCycles` fields for
    /// repeating timers and snoozing alarms.
    public static let currentSchemaVersion = 3

    public init(schemaVersion: Int = PersistedStore.currentSchemaVersion, items: [TimerItem] = []) {
        self.schemaVersion = schemaVersion
        self.items = items
    }

    /// An empty store at the current schema version. Used when no file exists
    /// or the existing file is unreadable/corrupt.
    public static var empty: PersistedStore {
        PersistedStore(schemaVersion: currentSchemaVersion, items: [])
    }
}