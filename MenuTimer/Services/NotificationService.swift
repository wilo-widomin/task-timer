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
        Self.installCustomSounds()
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

    /// Copies the bundled custom sounds into `~/Library/Sounds` so macOS can
    /// find them.
    ///
    /// Unlike iOS, `UNNotificationSound(named:)` on macOS does **not** reliably
    /// resolve sound files from the app bundle — it searches the standard
    /// `Library/Sounds` directories. A notification whose sound lives only in
    /// the bundle silently falls back to the default system sound. Installing a
    /// copy under the user's `Library/Sounds` makes the custom name resolve.
    private static func installCustomSounds() {
        let fileManager = FileManager.default
        guard let library = try? fileManager.url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }

        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
        do {
            try fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            NSLog("MenuTimer: could not create \(soundsDir.path): \(error.localizedDescription)")
            return
        }

        for name in [timerSoundName, alarmSoundName] {
            guard let source = Bundle.main.url(forResource: name, withExtension: nil) else {
                NSLog("MenuTimer: bundled sound '\(name)' not found in app bundle")
                continue
            }
            let destination = soundsDir.appendingPathComponent(name)

            // Skip the copy when an identical file is already installed; refresh
            // it otherwise so updated sounds ship to existing users.
            if let srcSize = fileSize(source), let dstSize = fileSize(destination), srcSize == dstSize {
                continue
            }
            try? fileManager.removeItem(at: destination)
            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                NSLog("MenuTimer: failed to install sound '\(name)': \(error.localizedDescription)")
            }
        }
    }

    private static func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

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
