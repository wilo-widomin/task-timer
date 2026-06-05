//
//  NotificationService.swift
//  MenuTimer
//
//  Thin wrapper over UserNotifications for requesting authorization and posting
//  a local notification when a timer or alarm fires.
//

import Foundation
import UserNotifications

/// Abstraction over local notifications so the store can be tested without the
/// real notification center.
@MainActor
public protocol NotificationServing: AnyObject {
    /// Requests authorization to post alerts and play sounds. Safe to call
    /// repeatedly; the system only prompts once.
    func requestAuthorization() async
    /// Posts a notification for an item that has just fired.
    func postNotification(for item: TimerItem)
}

/// `UNUserNotificationCenter`-backed implementation.
@MainActor
public final class NotificationService: NotificationServing {

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Authorization failures are non-fatal: the app still works, it
            // just won't post notifications.
            NSLog("MenuTimer: notification authorization failed: \(error.localizedDescription)")
        }
    }

    public func postNotification(for item: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = item.kind == .timer ? "Timer finished" : "Alarm"
        content.body = item.title
        content.sound = .default

        // Deliver immediately. `nil` trigger fires the request right away.
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                NSLog("MenuTimer: failed to post notification: \(error.localizedDescription)")
            }
        }
    }
}
