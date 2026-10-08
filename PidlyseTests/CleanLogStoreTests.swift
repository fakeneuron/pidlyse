import XCTest
import PidlyseCore
@testable import Pidlyse

/// App-side clean log must not clobber a CLI append (PID-079.2).
final class CleanLogStoreTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pidlyse-store-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private var logURL: URL {
        directory.appendingPathComponent("clean-log.json")
    }

    private func event(_ kind: String, at seconds: TimeInterval) -> CleanEvent {
        CleanEvent(kind: kind, projectLabel: "proj", rssKB: 100,
                   timestamp: Date(timeIntervalSince1970: 1_000_000 + seconds))
    }

    func testRecord_afterCLIAppend_keepsBothEvents() {
        let store = CleanLogStore(fileURL: logURL)
        CleanLogFile.append([event("cli", at: 0)], at: logURL)
        store.record(event("app", at: 10))
        XCTAssertEqual(store.events.map(\.kind), ["cli", "app"])
        XCTAssertEqual(CleanLogFile.load(from: logURL).map(\.kind), ["cli", "app"])
    }

    func testReload_picksUpCLIAppend() {
        let store = CleanLogStore(fileURL: logURL)
        CleanLogFile.append([event("cli", at: 0)], at: logURL)
        XCTAssertTrue(store.events.isEmpty)
        store.reload()
        XCTAssertEqual(store.events.map(\.kind), ["cli"])
    }
}
