import XCTest
@testable import PidlyseCore

final class CleanLogFileTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pidlyse-tests-\(UUID().uuidString)/clean-log.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func event(_ kind: String, at seconds: TimeInterval) -> CleanEvent {
        CleanEvent(kind: kind, projectLabel: "proj", rssKB: 100,
                   timestamp: Date(timeIntervalSince1970: 1_000_000 + seconds))
    }

    func testLoad_missingFile_returnsEmpty() {
        XCTAssertTrue(CleanLogFile.load(from: tempURL).isEmpty)
    }

    func testLoad_malformedJSON_returnsEmpty() throws {
        try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempURL)
        XCTAssertTrue(CleanLogFile.load(from: tempURL).isEmpty)
    }

    func testSaveLoad_roundTrip() {
        let events = [event("pytest", at: 0), event("npm", at: 10)]
        CleanLogFile.save(events, to: tempURL)
        XCTAssertEqual(CleanLogFile.load(from: tempURL), events)
    }

    func testAppend_mergesWithExisting_andPersists() {
        CleanLogFile.save([event("pytest", at: 0)], to: tempURL)
        let merged = CleanLogFile.append([event("npm", at: 10)], at: tempURL)
        XCTAssertEqual(merged.map { $0.kind }, ["pytest", "npm"])
        XCTAssertEqual(CleanLogFile.load(from: tempURL).map { $0.kind }, ["pytest", "npm"])
    }

    func testAppend_appliesCap_keepingNewest() {
        CleanLogFile.save([event("a", at: 0), event("b", at: 10)], to: tempURL)
        let merged = CleanLogFile.append([event("c", at: 20)], at: tempURL, cap: 2)
        XCTAssertEqual(merged.map { $0.kind }, ["b", "c"])
    }

    func testAppend_empty_isReadOnly() {
        // No directory is created and nothing is written for an empty append.
        XCTAssertTrue(CleanLogFile.append([], at: tempURL).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }

    /// The format contract both writers share: ISO-8601 dates, so a log written
    /// by the CLI decodes in the app's store (and vice versa).
    func testSave_writesISO8601Dates() throws {
        CleanLogFile.save([event("vite", at: 0)], to: tempURL)
        let json = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(json.contains("\"1970-01-12T13:46:40Z\""))
    }
}
