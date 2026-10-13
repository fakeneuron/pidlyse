import Darwin
import XCTest
import PidlyseCore
@testable import Pidlyse

/// App-side clean log must not clobber a CLI append (PID-079.2).
final class CleanLogStoreTests: XCTestCase {

    /// Written on the holder thread before it signals, read on the test thread after.
    private final class LockFlag: @unchecked Sendable {
        var value = false
    }

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
        waitUntil(store, equals: ["cli", "app"])
        XCTAssertEqual(CleanLogFile.load(from: logURL).map(\.kind), ["cli", "app"])
    }

    /// The kill callback calls `record` on the main thread. A peer holding the
    /// sibling lock must not stall that call. A second thread's `LOCK_EX` blocks
    /// on this OS (PID-084), so the holder stands in for the CLI. The release is
    /// on a timer so a regression that appends inline fails the elapsed check
    /// instead of deadlocking against the holder.
    func testRecord_returnsWhilePeerHoldsTheLock() throws {
        XCTAssertTrue(Thread.isMainThread)
        let store = CleanLogStore(fileURL: logURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockPath = logURL.appendingPathExtension("lock").path

        let ready = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let locked = LockFlag()
        DispatchQueue.global(qos: .userInitiated).async {
            let fd = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, mode_t(0o644))
            if fd >= 0, flock(fd, LOCK_EX) == 0 {
                locked.value = true
                ready.signal()
                release.wait()
                flock(fd, LOCK_UN)
                close(fd)
            } else {
                if fd >= 0 { close(fd) }
                ready.signal()
            }
        }
        XCTAssertEqual(ready.wait(timeout: .now() + 2), .success)
        XCTAssertTrue(locked.value, "peer did not take the lock")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) { release.signal() }

        let started = Date()
        store.record(event("one", at: 0))
        store.record(event("two", at: 1))
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.25)
        drainMain(for: 0.05)
        XCTAssertTrue(store.events.isEmpty, "published before the peer released the lock")

        waitUntil(store, equals: ["one", "two"])
        XCTAssertEqual(CleanLogFile.load(from: logURL).map(\.kind), ["one", "two"])
    }

    /// `DispatchQueue.main` work is not guaranteed to run inside `RunLoop.run`.
    /// Waiting on a block queued here drains everything already queued ahead of it.
    private func drainMain(for delay: TimeInterval) {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { drained.fulfill() }
        wait(for: [drained], timeout: delay + 1)
    }

    private func waitUntil(_ store: CleanLogStore, equals kinds: [String],
                           timeout: TimeInterval = 3,
                           file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if store.events.map(\.kind) == kinds { return }
            drainMain(for: 0.02)
        }
        XCTAssertEqual(store.events.map(\.kind), kinds, file: file, line: line)
    }

    func testReload_picksUpCLIAppend() {
        let store = CleanLogStore(fileURL: logURL)
        CleanLogFile.append([event("cli", at: 0)], at: logURL)
        XCTAssertTrue(store.events.isEmpty)
        store.reload()
        XCTAssertEqual(store.events.map(\.kind), ["cli"])
    }
}
