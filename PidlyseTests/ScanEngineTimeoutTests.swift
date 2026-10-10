import XCTest
@testable import Pidlyse
@testable import PidlyseCore

/// A scan whose every shell call expires must still publish and clear
/// `isScanning` (PID-079.3). `Shell.deadlineOverride = 0` forces that expiry
/// without touching the caller's `Shell.Budget` or the user's defaults.
final class ScanEngineTimeoutTests: XCTestCase {

    private var suiteName: String?

    override func tearDown() {
        Shell.deadlineOverride = nil
        if let suiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    func testTimedOutScanPublishesAndClearsIsScanning() {
        let name = "pidlyse-scan-timeout-\(UUID().uuidString)"
        suiteName = name
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Shell.deadlineOverride = 0

        let engine = ScanEngine(defaults: defaults)
        XCTAssertFalse(engine.isScanning)

        let done = expectation(description: "scan published")
        engine.scan {
            XCTAssertFalse(engine.isScanning)
            // A live `ps -axo` always contains launchd. An empty table means the
            // ancestry shell call expired and the scan still published.
            XCTAssertTrue(engine.processTable.isEmpty)
            XCTAssertTrue(engine.items.isEmpty)
            done.fulfill()
        }
        XCTAssertTrue(engine.isScanning)

        wait(for: [done], timeout: 30)
        XCTAssertFalse(engine.isScanning)
        XCTAssertTrue(engine.processTable.isEmpty)
        XCTAssertTrue(engine.items.isEmpty)
    }

    func testAfterInitialScanWaitsForPublishedSnapshot() {
        let name = "pidlyse-initial-scan-\(UUID().uuidString)"
        suiteName = name
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Shell.deadlineOverride = 0

        let engine = ScanEngine(defaults: defaults)
        let published = expectation(description: "initial scan published")
        engine.afterInitialScan {
            XCTAssertFalse(engine.isScanning)
            published.fulfill()
        }

        engine.scan()
        XCTAssertTrue(engine.isScanning)
        wait(for: [published], timeout: 30)

        let immediate = expectation(description: "completed initial scan is immediate")
        engine.afterInitialScan { immediate.fulfill() }
        wait(for: [immediate], timeout: 0)
    }
}
