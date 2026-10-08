import XCTest
@testable import PidlyseCore

/// Test for the PID-35.3 scan-time start-time capture: an injected provider
/// populates `ProcessItem.startTime`; the default (no provider) leaves it `nil`.
final class ScanCoreStartTimeTests: XCTestCase {

    private let line = "1234 1 10:00 ?? 0.0 1000 pytest tests/"

    func testEnumerate_withProvider_populatesStartTime() {
        let token = ProcStartTime(sec: 42, usec: 7)
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line,
                                       registeredPIDs: [],
                                       startTimeProvider: { _ in token })
        XCTAssertEqual(items.first?.startTime, token)
    }

    func testEnumerate_withoutProvider_startTimeNil() {
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line,
                                       registeredPIDs: [])
        XCTAssertNil(items.first?.startTime)
    }
}
