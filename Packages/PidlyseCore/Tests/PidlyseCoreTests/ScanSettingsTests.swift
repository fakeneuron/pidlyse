import XCTest
@testable import PidlyseCore

final class ScanSettingsTests: XCTestCase {

    private func makeSuite() -> UserDefaults {
        let name = "pidlyse-079-7-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        addTeardownBlock { suite.removePersistentDomain(forName: name) }
        return suite
    }

    // MARK: - Key strings (PID-079.7)

    /// The key strings are persisted user data — a rename orphans every saved
    /// setting — so they are pinned here, not just defined once.
    func testSettingsKey_stringsArePersistedContract() {
        XCTAssertEqual(SettingsKey.elapsedThreshold, "elapsedThreshold")
        XCTAssertEqual(SettingsKey.ignoredNames, "ignoredNames")
        XCTAssertEqual(SettingsKey.disabledKinds, "disabledKinds")
        XCTAssertEqual(SettingsKey.customRules, "customRules")
        XCTAssertEqual(SettingsKey.protectedProjects, "protectedProjects")
    }

    // MARK: - Load

    func testLoad_emptyDomain_isDefaults() {
        XCTAssertEqual(ScanSettings.load(from: makeSuite()), ScanSettings())
    }

    func testLoad_readsEveryKey() {
        let suite = makeSuite()
        suite.set(600.0, forKey: SettingsKey.elapsedThreshold)
        suite.set(["chrome", "node @ ~/code/bidviz"], forKey: SettingsKey.ignoredNames)
        suite.set(["docker"], forKey: SettingsKey.disabledKinds)
        suite.set(["foo = Foo Thing"], forKey: SettingsKey.customRules)
        suite.set(["~/code/probe"], forKey: SettingsKey.protectedProjects)

        let loaded = ScanSettings.load(from: suite)

        XCTAssertEqual(loaded.elapsedThreshold, 600)
        XCTAssertEqual(loaded.ignoredNames, ["chrome", "node @ ~/code/bidviz"])
        XCTAssertEqual(loaded.disabledKinds, [.docker])
        XCTAssertEqual(loaded.customRules, [CustomRule.parse("foo = Foo Thing")!])
        XCTAssertEqual(loaded.protectedProjects, ["~/code/probe"])
    }

    func testLoad_nonPositiveThreshold_isUnset() {
        let suite = makeSuite()
        suite.set(0.0, forKey: SettingsKey.elapsedThreshold)
        XCTAssertNil(ScanSettings.load(from: suite).elapsedThreshold)
        suite.set(-5.0, forKey: SettingsKey.elapsedThreshold)
        XCTAssertNil(ScanSettings.load(from: suite).elapsedThreshold)
    }

    func testLoad_unknownKindRawValue_isDropped() {
        let suite = makeSuite()
        suite.set(["docker", "no-such-kind"], forKey: SettingsKey.disabledKinds)
        XCTAssertEqual(ScanSettings.load(from: suite).disabledKinds, [.docker])
    }

    // MARK: - Request

    func testRequest_unsetThreshold_usesCoreDefault() {
        XCTAssertEqual(ScanSettings().request.elapsedThreshold, ScanCore.defaultElapsedThreshold)
    }

    func testRequest_parsesIgnoreRules_andCarriesKindsAndCustomRules() {
        let rule = CustomRule.parse("foo = Foo Thing")!
        let settings = ScanSettings(elapsedThreshold: 90,
                                    ignoredNames: ["chrome", "node @ ~/code/bidviz", "  "],
                                    disabledKinds: [.docker],
                                    customRules: [rule],
                                    protectedProjects: ["~/code/probe"])

        let request = settings.request

        XCTAssertEqual(request.elapsedThreshold, 90)
        XCTAssertEqual(request.ignoreRules, [IgnoreRule(substring: "chrome"),
                                             IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz")])
        XCTAssertEqual(request.disabledKinds, [.docker])
        XCTAssertEqual(request.customRules, [rule])
        XCTAssertTrue(request.dismissedPIDs.isEmpty)
    }
}
