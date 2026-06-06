//
//  AppInfo.swift
//  MenuTimer
//
//  Reads display metadata from the bundle.
//

import Foundation

/// Static, bundle-derived app metadata.
public enum AppInfo {
    /// Human-readable app name.
    public static let name = "Menu Timer"

    /// The author/credit line shown in the About window.
    public static let author = "Built with AppKit + SwiftUI"

    /// Marketing version from the bundle's `CFBundleShortVersionString`,
    /// e.g. `"1.0.6"`. Never hardcoded — falls back to `"—"` only if the
    /// bundle somehow lacks the key.
    public static var shortVersion: String {
        bundleString("CFBundleShortVersionString") ?? "—"
    }

    /// Build number from the bundle's `CFBundleVersion`, e.g. `"1"`.
    public static var buildNumber: String {
        bundleString("CFBundleVersion") ?? "—"
    }

    /// Combined version string, e.g. `"Version 1.0.6 (1)"`.
    public static var versionDescription: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    /// Reads a string from the bundle's Info dictionary.
    ///
    /// Tries the localized info dictionary first (`object(forInfoDictionaryKey:)`)
    /// then the raw `infoDictionary`. They normally agree, but the localized
    /// lookup can miss build-variable-substituted keys like the version in some
    /// build configurations, so the raw dictionary is a reliable backstop.
    private static func bundleString(_ key: String) -> String? {
        if let localized = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !localized.isEmpty {
            return localized
        }
        if let raw = Bundle.main.infoDictionary?[key] as? String, !raw.isEmpty {
            return raw
        }
        return nil
    }
}
