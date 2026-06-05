//
//  TestDoubles.swift
//  MenuTimerTests
//
//  Shared in-memory fakes for store-level tests.
//

import Foundation
@testable import MenuTimer

/// In-memory persistence backend that records the last saved store.
actor InMemoryPersistence: PersistenceService {
    private(set) var stored: PersistedStore
    private(set) var saveCount = 0

    init(initial: PersistedStore = .empty) {
        self.stored = initial
    }

    func load() async -> PersistedStore { stored }

    func save(_ store: PersistedStore) async throws {
        stored = store
        saveCount += 1
    }
}

/// Records notifications instead of posting them to the system.
@MainActor
final class SpyNotificationService: NotificationServing {
    private(set) var authorizationRequested = false
    private(set) var posted: [TimerItem] = []

    func requestAuthorization() async {
        authorizationRequested = true
    }

    func postNotification(for item: TimerItem) {
        posted.append(item)
    }
}
