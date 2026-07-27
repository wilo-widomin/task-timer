import Foundation

/// Static, bundle-derived app metadata.
/// Reads from the host bundle — works for both standalone MenuTimer and Widomin module.
public enum AppInfo {
    /// Human-readable app name.
    public static let name = "Menu Timer"

    /// The author/credit line shown in the About window.
    public static let author = "Built with AppKit + SwiftUI"

    /// Marketing version from the bundle's `CFBundleShortVersionString`.
    public static var shortVersion: String {
        bundleString("CFBundleShortVersionString") ?? "—"
    }

    /// Build number from the bundle's `CFBundleVersion`.
    public static var buildNumber: String {
        bundleString("CFBundleVersion") ?? "—"
    }

    /// Combined version string, e.g. `"Version 1.6.1 (1)"`.
    public static var versionDescription: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

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