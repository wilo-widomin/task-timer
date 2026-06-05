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

    /// Marketing version, e.g. `"1.0"`.
    public static var shortVersion: String {
        bundleString("CFBundleShortVersionString") ?? "1.0"
    }

    /// Build number, e.g. `"1"`.
    public static var buildNumber: String {
        bundleString("CFBundleVersion") ?? "1"
    }

    /// Combined version string, e.g. `"Version 1.0 (1)"`.
    public static var versionDescription: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    private static func bundleString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
