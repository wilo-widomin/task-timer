//
//  NotificationService.swift
//  MenuTimer
//
//  Thin wrapper over UserNotifications for requesting authorization and posting
//  a local notification when a timer or alarm fires. The alert sound is played
//  directly via NSSound rather than through UNNotificationSound, because custom
//  notification sounds are unreliable on macOS.
//

import AppKit
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

    /// Sounds currently playing, retained so ARC does not deallocate them
    /// mid-playback. Cleared as each one finishes (see `NSSoundDelegate`).
    private var activeSounds: [PlayingSound] = []

    /// A playing sound plus how many more times it should replay when it ends.
    @MainActor
    private final class PlayingSound {
        let sound: NSSound
        var remainingReplays: Int
        public init(sound: NSSound, remainingReplays: Int) {
            self.sound = sound
            self.remainingReplays = remainingReplays
        }
    }

    /// Number of times the alarm sound plays in total.
    private static let alarmRepeatCount = 3

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        // Become the center's delegate so the banner still presents while
        // MenuTimer is the active app; otherwise macOS suppresses foreground
        // notifications — a common case for a menu-bar app, since firing a
        // timer often coincides with the user interacting with the menu.
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

    /// Bundled sound file for timer notifications.
    private static let timerSoundName = "timer_sound.wav"
    /// Bundled sound file for alarm notifications.
    private static let alarmSoundName = "alarm_sound.wav"

    public func postNotification(for item: TimerItem) {
        // Play the alert sound ourselves. Custom `UNNotificationSound` files are
        // unreliable on macOS (the system frequently ignores bundle sounds and
        // falls back to the default), so we drive playback directly and post a
        // silent notification. Trade-off: this bypasses Do Not Disturb / Focus,
        // which is acceptable for a timer/alarm — if you set one, you want it
        // to sound.
        playSound(for: item)

        let content = UNMutableNotificationContent()
        content.title = item.kind == .timer ? "Timer finished" : "Alarm"
        content.body = item.title
        // Silent: the sound is handled by `playSound(for:)` above.
        content.sound = nil
        // Persistent alert: a time-sensitive notification stays on screen until
        // the user dismisses it rather than auto-dismissing like a transient
        // banner. (`.critical` would be even more insistent but needs a
        // special, Apple-approved entitlement, so we use `.timeSensitive`.)
        content.interruptionLevel = .timeSensitive

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

    /// Plays the bundled alert sound for the item's kind. The alarm sound
    /// repeats (see `alarmRepeatCount`); the timer sound plays once.
    private func playSound(for item: TimerItem) {
        let name = item.kind == .timer ? Self.timerSoundName : Self.alarmSoundName
        // `Bundle.module` y no `Bundle.main`: al consumirse como paquete, el bundle
        // principal es el de la app anfitriona, que no lleva estos sonidos. Esta
        // línea es la única divergencia intencionada con la copia de `MenuTimer/`,
        // donde `Bundle.module` ni siquiera existe.
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: nil),
              let sound = NSSound(contentsOf: url, byReference: true) else {
            NSLog("MenuTimer: could not load bundled sound '\(name)'")
            return
        }
        let totalPlays = item.kind == .alarm ? Self.alarmRepeatCount : 1
        sound.delegate = self
        // Retain until playback finishes so overlapping timers each get heard.
        activeSounds.append(PlayingSound(sound: sound, remainingReplays: totalPlays - 1))
        sound.play()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Present the banner even when MenuTimer is the foreground app; the sound
    /// is played separately via `NSSound`, so no `.sound` option here.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

// MARK: - NSSoundDelegate

extension NotificationService: NSSoundDelegate {

    nonisolated public func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        Task { @MainActor in
            guard let index = activeSounds.firstIndex(where: { $0.sound === sound }) else { return }
            // Replay until the requested count is reached; otherwise release it.
            if finished, activeSounds[index].remainingReplays > 0 {
                activeSounds[index].remainingReplays -= 1
                sound.play()
            } else {
                activeSounds.remove(at: index)
            }
        }
    }
}
