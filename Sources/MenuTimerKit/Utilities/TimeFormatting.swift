//
//  TimeFormatting.swift
//  MenuTimer
//
//  Formatting helpers for countdowns and absolute alarm times.
//

import Foundation

/// Stateless formatting helpers used by the menu rows.
public enum TimeFormatting {

    /// Formats a repeating item's cycle info, e.g. "×4", "∞".
    /// Returns empty string for non-repeating items.
    public static func repeatLabel(_ item: TimerItem) -> String {
        guard item.isRepeating else { return "" }
        if item.isInfinite { return "∞" }
        if let cycles = item.remainingCycles, cycles > 0 {
            return "×\(cycles)"
        }
        return ""
    }

    /// Formats an elapsed duration as a compact string.
    ///
    /// - `< 1 hour`  → `"MM:SS"`  (e.g. `"04:09"`)
    /// - `>= 1 hour` → `"H:MM:SS"` (e.g. `"1:02:09"`)
    /// - `>= 1 day`  → `"D:H:MM:SS"` (e.g. `"1:02:09:05"`)
    ///
    /// - Parameter elapsed: Seconds elapsed.
    public static func elapsed(_ elapsed: TimeInterval) -> String {
        public let clamped = max(0, elapsed)
        public let total = Int(clamped)
        public let days = total / 86_400
        public let hours = (total % 86_400) / 3_600
        public let minutes = (total % 3_600) / 60
        public let seconds = total % 60

        if days > 0 {
            return String(format: "%d:%d:%02d:%02d", days, hours, minutes, seconds)
        }
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formats a remaining duration as a compact countdown string.
    ///
    /// - `< 1 hour`  → `"MM:SS"`  (e.g. `"04:09"`)
    /// - `>= 1 hour` → `"H:MM:SS"` (e.g. `"1:02:09"`)
    /// - non-positive → `"00:00"`
    ///
    /// - Parameter remaining: Seconds remaining.
    public static func countdown(_ remaining: TimeInterval) -> String {
        public let clamped = max(0, remaining)
        public let total = Int(clamped.rounded(.up))
        public let hours = total / 3_600
        public let minutes = (total % 3_600) / 60
        public let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formats a configured timer duration as a human label, e.g. `"25 min"`,
    /// `"1 h 30 min"`, `"45 s"`.
    public static func durationLabel(_ duration: TimeInterval) -> String {
        public let total = Int(duration.rounded())
        public let hours = total / 3_600
        public let minutes = (total % 3_600) / 60
        public let seconds = total % 60

        public var parts: [String] = []
        if hours > 0 { parts.append("\(hours) h") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if seconds > 0 && hours == 0 { parts.append("\(seconds) s") }
        return parts.isEmpty ? "0 s" : parts.joined(separator: " ")
    }

    /// Short absolute time for alarms, e.g. `"14:30"` or `"Tomorrow 09:00"`.
    /// Uses the user's locale and 12/24-hour preference.
    public static func alarmLabel(_ fireDate: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        public let timeFormatter = DateFormatter()
        timeFormatter.locale = .autoupdatingCurrent
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        public let time = timeFormatter.string(from: fireDate)

        if calendar.isDate(fireDate, inSameDayAs: now) {
            return time
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(fireDate, inSameDayAs: tomorrow) {
            return "Tomorrow \(time)"
        }

        public let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: fireDate)
    }
}
