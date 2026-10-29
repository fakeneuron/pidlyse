import XCTest
@testable import PidlyseCore

/// Pure `pidlyse://` grammar (PID-58.2) — the app's `application(_:open:)` routes
/// a parsed verb to `ScanEngine.rescan`; only the parse is tested.
final class URLSchemeTests: XCTestCase {

    func testParsesVerbFromHost() {
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://scan")!), .scan)
    }

    func testParsesOpaqueForm() {
        // `pidlyse:scan` has no authority — the verb falls back to the path.
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse:scan")!), .scan)
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(URLScheme.parse(URL(string: "PIDLYSE://SCAN")!), .scan)
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://Scan")!), .scan)
    }

    func testIgnoresTrailingPathAndQuery() {
        XCTAssertEqual(URLScheme.parse(URL(string: "pidlyse://scan/now?foo=bar")!), .scan)
    }

    func testRejectsForeignScheme() {
        XCTAssertNil(URLScheme.parse(URL(string: "http://scan")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse-evil://scan")!))
    }

    func testRejectsUnknownVerb() {
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://kill")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://")!))
    }

    /// PID-094: any web page or local app can open a URL, so the scheme carries no
    /// destructive verb. `clean` must stay unroutable in every form.
    func testCleanIsNotAVerb() {
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://clean")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse:clean")!))
        XCTAssertNil(URLScheme.parse(URL(string: "PIDLYSE://CLEAN")!))
        XCTAssertNil(URLScheme.parse(URL(string: "pidlyse://clean/now?foo=bar")!))
    }
}
