import XCTest
@testable import PidlyseCore

final class CustomRuleTests: XCTestCase {

    // MARK: - CustomRule parsing / matching (PID-54.3)

    func testCustomRule_parse_substringAndLabel() {
        let rule = CustomRule.parse("my-worker = My Background Worker")
        XCTAssertEqual(rule, CustomRule(substring: "my-worker", label: "My Background Worker"))
    }

    func testCustomRule_parse_bareSubstring_labelFallsBackToSubstring() {
        let rule = CustomRule.parse("  sync-daemon  ")
        XCTAssertEqual(rule, CustomRule(substring: "sync-daemon", label: "sync-daemon"))
    }

    func testCustomRule_parse_emptySubstring_isNil() {
        XCTAssertNil(CustomRule.parse(""))
        XCTAssertNil(CustomRule.parse("   "))
        XCTAssertNil(CustomRule.parse(" = orphan label"))
    }

    func testCustomRule_serialize_roundTrip() {
        let rule = CustomRule(substring: "my-worker", label: "My Worker")
        XCTAssertEqual(CustomRule.serialize(rule), "my-worker = My Worker")
        XCTAssertEqual(CustomRule.parse(CustomRule.serialize(rule)), rule)
    }

    func testCustomRule_firstMatch_caseInsensitive_firstWins() {
        let rules = [CustomRule(substring: "worker", label: "First"),
                     CustomRule(substring: "my-worker", label: "Second")]
        // Both substrings appear; the earlier rule wins.
        XCTAssertEqual(CustomRule.firstMatch("node MY-WORKER.js", in: rules)?.label, "First")
        XCTAssertNil(CustomRule.firstMatch("node server.js", in: rules))
    }

    // MARK: - customRules classification via enumerate (PID-54.3)

    func testEnumerate_customRule_catchesOtherwiseUnmatchedProcess() {
        // A bare `my-daemon` matches no built-in kind → normally excluded.
        let output = "  4000     1 01:46:38 ??   0.0  4096   /opt/app/my-daemon --serve"
        XCTAssertEqual(ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output).count, 0)

        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output,
                                       customRules: [CustomRule(substring: "my-daemon", label: "My Daemon")])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .custom)
        XCTAssertEqual(items.first?.customLabel, "My Daemon")
        XCTAssertEqual(items.first?.displayLabel, "My Daemon")
    }

    func testEnumerate_customRule_winsOverBuiltinKind() {
        // `node my-worker.js` is a built-in `.node`; the custom rule relabels it.
        let output = "  4000     1 01:46:38 ??   0.0  4096   node /app/my-worker.js"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output,
                                       customRules: [CustomRule(substring: "my-worker", label: "My Worker")])
        XCTAssertEqual(items.first?.kind, .custom)
        XCTAssertEqual(items.first?.customLabel, "My Worker")
    }

    func testEnumerate_customRule_alwaysNeedsReview_evenAsStrongStray() {
        // Orphaned + old + no TTY would be an easy/safe test-runner, but a custom
        // match is forced to moderate → needsReview (never auto-killable).
        let output = "  4000     1 01:46:38 ??   0.0  4096   /opt/app/my-daemon --serve"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output,
                                       customRules: [CustomRule(substring: "my-daemon", label: "My Daemon")])
        XCTAssertEqual(items.first?.riskTier, .moderate)
        XCTAssertEqual(items.first?.bucket, .needsReview)
    }

    func testEnumerate_customRules_empty_noCustomMatches() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   node /app/server.js"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output, customRules: [])
        XCTAssertEqual(items.first?.kind, .node)
        XCTAssertNil(items.first?.customLabel)
    }
}
