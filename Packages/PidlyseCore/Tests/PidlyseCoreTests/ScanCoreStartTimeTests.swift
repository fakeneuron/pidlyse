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

    // MARK: - argv capture (PID-087)

    func testEnumerate_argvProvider_populatesArgvWhenItAgreesWithPS() {
        let argv = ["node", "/My Apps/api/node_modules/.bin/vite"]
        let psLine = "1234 1 10:00 ?? 0.0 1000 \(argv.joined(separator: " "))"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: psLine,
                                       registeredPIDs: [], argvProvider: { _ in argv })
        XCTAssertEqual(items.first?.argv, argv)
        XCTAssertEqual(items.first?.displayName, "Vite dev server")
    }

    func testEnumerate_argvProvider_disagreeingArgvIsDropped() {
        // A PID recycled between `ps` and `sysctl` would hand back someone else's argv.
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line,
                                       registeredPIDs: [],
                                       argvProvider: { _ in ["node", "/other/process.js"] })
        XCTAssertNil(items.first?.argv)
    }

    func testEnumerate_withoutArgvProvider_argvNil() {
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line, registeredPIDs: [])
        XCTAssertNil(items.first?.argv)
    }

    func testCollapseTrees_groupCarriesRepresentativeArgv() {
        let argv = ["node", "/My Apps/api/node_modules/.bin/vite"]
        let shell = ProcessItem(pid: 10, ppid: 1, command: "sh -c vite", elapsed: 0, tty: "??",
                                kind: .vite, riskTier: .moderate, cpuPercent: 0, rssKB: 0)
        let vite = ProcessItem(pid: 11, ppid: 10, command: argv.joined(separator: " "), elapsed: 0,
                               tty: "??", kind: .vite, riskTier: .moderate, cpuPercent: 0, rssKB: 0,
                               argv: argv)
        let group = ScanCore.collapseTrees([shell, vite])
        XCTAssertEqual(group.count, 1)
        XCTAssertEqual(group.first?.argv, argv)
        XCTAssertEqual(group.first?.displayName, "Vite dev server")
    }
}
