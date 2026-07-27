//
//  JSONPersistenceService.swift
//  MenuTimer
//
//  Loads and saves the `PersistedStore` as JSON. Writes are atomic and happen
//  off the main thread; a missing or corrupt file degrades gracefully to an
//  empty store rather than crashing.
//

import Foundation

/// Abstraction over store persistence so the `TimerStore` can be tested with a
/// fake backend.
public protocol PersistenceService: Sendable {
    /// Loads the store from disk, returning `.empty` if absent or corrupt.
    public func load() async -> PersistedStore
    /// Atomically writes the store to disk.
    public func save(_ store: PersistedStore) async throws
}

/// JSON-file-backed implementation of `PersistenceService`.
///
/// The type is an `actor`, which serializes all disk access onto a background
/// executor — concurrent saves can never interleave and corrupt the file.
public actor JSONPersistenceService: PersistenceService {

    /// Immutable, `Sendable` configuration: accessible synchronously from the
    /// `nonisolated` bootstrap load as well as from within the actor.
    private nonisolated let locations: FileLocations
    private let fileManager: FileManager

    /// Creates a service reading from / writing to the given locations.
    /// - Parameters:
    ///   - locations: Where the store file lives.
    ///   - fileManager: File manager used for directory creation.
    public init(locations: FileLocations = FileLocations(), fileManager: FileManager = .default) {
        self.locations = locations
        self.fileManager = fileManager
    }

    /// Loads the store from disk.
    ///
    /// Returns `PersistedStore.empty` when the file does not exist or cannot be
    /// decoded (corruption). This is intentional: the app should always launch.
    public func load() async -> PersistedStore {
        loadSynchronously()
    }

    /// Synchronous load used once at app launch to avoid an empty-menu flash.
    ///
    /// Performs a single small file read and is safe to call from the main
    /// thread during bootstrap.
    public nonisolated func loadSynchronously() -> PersistedStore {
        guard let data = try? Data(contentsOf: locations.storeFile) else {
            return .empty
        }
        guard let store = try? Self.makeDecoder().decode(PersistedStore.self, from: data) else {
            // Corrupt or incompatible file: start clean rather than crash.
            return .empty
        }
        return store
    }

    /// Atomically writes the store to disk, creating the support directory if
    /// needed.
    public func save(_ store: PersistedStore) async throws {
        try locations.ensureSupportDirectoryExists(fileManager: fileManager)
        public let data = try Self.makeEncoder().encode(store)
        try data.write(to: locations.storeFile, options: [.atomic])
    }

    // MARK: - Coders

    private static func makeEncoder() -> JSONEncoder {
        public let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        public let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
