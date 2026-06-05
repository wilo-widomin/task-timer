//
//  JSONPersistenceServiceTests.swift
//  MenuTimerTests
//
//  Tests persistence round-tripping, corrupt-file recovery, missing-file
//  behaviour and schema preservation. Each test uses an isolated temporary
//  directory.
//

import XCTest
@testable import MenuTimer

final class JSONPersistenceServiceTests: XCTestCase {

    private var tempDir: URL!
    private var locations: FileLocations!
    private var service: JSONPersistenceService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MenuTimerTests-\(UUID().uuidString)", isDirectory: true)
        locations = FileLocations(supportDirectory: tempDir)
        service = JSONPersistenceService(locations: locations)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testLoadMissingFileReturnsEmptyStore() async {
        let store = await service.load()
        XCTAssertEqual(store, .empty)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testSaveThenLoadRoundTrip() async throws {
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)
        let original = PersistedStore(items: [
            .timer(title: "Pasta", duration: 600, now: epoch),
            .alarm(title: "Standup", fireDate: epoch.addingTimeInterval(7_200), now: epoch),
        ])

        try await service.save(original)
        let loaded = await service.load()

        XCTAssertEqual(loaded, original)
        XCTAssertEqual(loaded.items.count, 2)
        XCTAssertEqual(loaded.items[0].title, "Pasta")
        XCTAssertEqual(loaded.items[0].configuredDuration, 600)
        XCTAssertEqual(loaded.items[1].kind, .alarm)
    }

    func testCorruptFileReturnsEmptyStore() async throws {
        try locations.ensureSupportDirectoryExists()
        try Data("this is not json {{{".utf8).write(to: locations.storeFile)

        let store = await service.load()
        XCTAssertEqual(store, .empty)
    }

    func testSchemaVersionIsPreserved() async throws {
        var store = PersistedStore.empty
        store.schemaVersion = 1
        store.items = [.timer(title: "X", duration: 60)]

        try await service.save(store)
        let loaded = await service.load()

        XCTAssertEqual(loaded.schemaVersion, PersistedStore.currentSchemaVersion)
    }

    func testSaveCreatesSupportDirectory() async throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))
        try await service.save(.empty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.storeFile.path))
    }

    func testSaveIsAtomicAndOverwrites() async throws {
        try await service.save(PersistedStore(items: [.timer(title: "First", duration: 60)]))
        try await service.save(PersistedStore(items: [.timer(title: "Second", duration: 90)]))

        let loaded = await service.load()
        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items.first?.title, "Second")
    }
}
