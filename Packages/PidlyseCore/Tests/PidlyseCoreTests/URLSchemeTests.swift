import XCTest
@testable import PidlyseCore

/// Pure `pidlyse://` grammar (PID-58.2) — the app's `application(_:open:)` routes
/// a parsed verb to `ScanEngine.cleanAllSafe` / `rescan`; only the parse is tested.
final class URLSchemeTests: XCTestCase {

    func testParsesVerbsFromHost() {
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://clean")!), .clean)
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://scan")!), .scan)
    }

    func testParsesOpaqueForm() {
        // `pidlyse:clean` has no authority — the verb falls back to the path.
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse:clean")!), .clean)
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse:scan")!), .scan)
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(URLScheme.parse(URL(string: "PIDLYSE://CLEAN")!), .clean)
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://Scan")!), .scan)
    }

    func testIgnoresTrailingPathAndQuery() {
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://clean/now?foo=bar")!), .clean)
    }

    func testRejectsForeignScheme() {
        XCTAssertNil(URLScheme.parse(URL(string: "http://clean")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse-evil://clean")!))
    }

    func testRejectsUnknownVerb() {
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://kill")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://")!))
    }
}
