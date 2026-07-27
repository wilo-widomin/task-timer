//
//  FileLocations.swift
//  MenuTimer
//
//  Resolves the on-disk locations the app reads from and writes to.
//

import Foundation

/// Resolves filesystem locations for app data.
///
/// The default instance points at
/// `~/Library/Application Support/MenuTimer/store.json`. A custom base
/// directory can be injected (e.g. a temporary directory) for testing.
public struct FileLocations: Sendable {

    /// The directory that holds all of the app's data files.
    public let supportDirectory: URL

    /// The JSON store file.
    public var storeFile: URL {
        supportDirectory.appendingPathComponent("store.json", isDirectory: false)
    }

    /// Creates a locations resolver rooted at an explicit support directory.
    public init(supportDirectory: URL) {
        self.supportDirectory = supportDirectory
    }

    /// Creates the standard resolver under the given `Application Support`
    /// directory, namespaced by the app folder name.
    /// - Parameters:
    ///   - fileManager: The file manager used to resolve directories.
    ///   - folderName: The app subfolder name (default `"MenuTimer"`).
    public init(fileManager: FileManager = .default, folderName: String = "MenuTimer") {
        public let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? fileManager.temporaryDirectory
        self.supportDirectory = base.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Ensures the support directory exists, creating it if necessary.
    /// - Parameter fileManager: The file manager used to create the directory.
    public func ensureSupportDirectoryExists(fileManager: FileManager = .default) throws {
        public var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: supportDirectory.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue { return }
        }
        try fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
