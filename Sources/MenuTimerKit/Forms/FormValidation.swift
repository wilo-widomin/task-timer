//
//  FormValidation.swift
//  MenuTimer
//
//  Pure validation rules shared by the SwiftUI forms, factored out so they can
//  be unit-tested independently of the view layer.
//

import Foundation

/// Stateless validation for the Add Timer / Add Alarm forms.
public enum FormValidation {

    /// Converts hours and minutes into a total duration in seconds.
    /// Negative inputs are clamped to zero.
    public static func duration(hours: Int, minutes: Int) -> TimeInterval {
        TimeInterval(max(0, hours) * 3_600 + max(0, minutes) * 60)
    }

    /// Trims surrounding whitespace/newlines from a title.
    public static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A timer is valid when its duration is positive and its title non-empty.
    public static func isValidTimer(hours: Int, minutes: Int, title: String) -> Bool {
        duration(hours: hours, minutes: minutes) > 0 && !normalizedTitle(title).isEmpty
    }

    /// An alarm is valid when its fire date is strictly in the future and its
    /// title is non-empty.
    public static func isValidAlarm(fireDate: Date, title: String, now: Date) -> Bool {
        fireDate > now && !normalizedTitle(title).isEmpty
    }
}
