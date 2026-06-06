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
public final class NotificationService: NSObject, NotificationServing {

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        // Become the center's delegate so notifications also present (banner +
        // sound) while MenuTimer is the active app. Without this, the system
        // silently suppresses foreground notifications — a common case for a
        // menu-bar app, since firing a timer often coincides with the user
        // interacting with the menu.
        center.delegate = self
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

    /// Name of the custom sound for timer notifications.
    private static let timerSoundName = "timer_sound.wav"
    /// Name of the custom sound for alarm notifications.
    private static let alarmSoundName = "alarm_sound.wav"

    public func postNotification(for item: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = item.kind == .timer ? "Timer finished" : "Alarm"
        content.body = item.title

        // Retro sounds: electronic beep for timers, analog bell for alarms.
        let soundName = item.kind == .timer ? Self.timerSoundName : Self.alarmSoundName
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))

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

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Present alerts and play the custom sound even when MenuTimer is the
    /// foreground app; otherwise macOS suppresses them.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
