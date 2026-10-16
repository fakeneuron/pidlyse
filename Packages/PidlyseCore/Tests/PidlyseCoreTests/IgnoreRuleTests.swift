import XCTest
@testable import PidlyseCore

final class IgnoreRuleTests: XCTestCase {

    // MARK: - IgnoreRule parsing / serialization (PID-54.4)

    func testIgnoreRule_parse_bareLine_isGlobal() {
        XCTAssertEqual(IgnoreRule.parse("chrome"), IgnoreRule(substring: "chrome", pathPrefix: nil))
    }

    func testIgnoreRule_parse_scopedLine_splitsSubstringAndPrefix() {
        XCTAssertEqual(IgnoreRule.parse("node @ ~/code/bidviz"),
                       IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz"))
    }

    func testIgnoreRule_parse_emptySubstring_isNil() {
        XCTAssertNil(IgnoreRule.parse(""))
        XCTAssertNil(IgnoreRule.parse("   "))
        XCTAssertNil(IgnoreRule.parse(" @ ~/code/bidviz"))
    }

    func testIgnoreRule_parse_emptyPrefix_degradesToGlobal() {
        XCTAssertEqual(IgnoreRule.parse("node @ "), IgnoreRule(substring: "node", pathPrefix: nil))
    }

    func testIgnoreRule_serialize_roundTrip() {
        XCTAssertEqual(IgnoreRule.serialize(IgnoreRule(substring: "chrome")), "chrome")
        let scoped = IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz")
        XCTAssertEqual(IgnoreRule.serialize(scoped), "node @ ~/code/bidviz")
        XCTAssertEqual(IgnoreRule.parse(IgnoreRule.serialize(scoped)), scoped)
    }
}
