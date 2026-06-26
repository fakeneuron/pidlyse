import XCTest
import PidlyCore

final class HelperConfigTests: XCTestCase {

    func testDecodeNilReturnsDefault() {
        XCTAssertEqual(HelperConfig.decode(nil), HelperConfig.default)
    }

    func testDecodeMalformedReturnsDefault() {
        let junk = Data("not json".utf8)
        XCTAssertEqual(HelperConfig.decode(junk), HelperConfig.default)
    }

    func testDecodeEmptyObjectReturnsDefault() {
        // Empty object is missing required keys → decode fails → default.
        let empty = Data("{}".utf8)
        XCTAssertEqual(HelperConfig.decode(empty), HelperConfig.default)
    }

    func testDecodePartialObjectReturnsDefault() {
        // All-or-nothing: a missing key fails the whole decode → default.
        let partial = Data(#"{"elapsedThreshold": 600, "ignoredNames": []}"#.utf8)
        XCTAssertEqual(HelperConfig.decode(partial), HelperConfig.default)
    }

    func testDecodeValidConfigRoundTrips() throws {
        let original = HelperConfig(elapsedThreshold: 600,
                                    ignoredNames: ["node", "vite"],
                                    notificationsEnabled: true)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(HelperConfig.decode(data), original)
    }

    func testDefaultMatchesScanCoreThreshold() {
        XCTAssertEqual(HelperConfig.default.elapsedThreshold, ScanCore.defaultElapsedThreshold)
        XCTAssertEqual(HelperConfig.default.ignoredNames, [])
        XCTAssertFalse(HelperConfig.default.notificationsEnabled)
    }
}
