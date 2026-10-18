import XCTest
@testable import PidlyseCore

// MARK: - Shared scan pipeline (PID-079.6)

/// The pure halves of the pipeline both consumers share: the request's ignore split
/// and the protected / sweep predicates. `ScanPipeline.run` itself only sequences
/// already-tested core calls against the live system; `ScanEngineTimeoutTests`
/// drives it through the app's default scan source.
final class ScanPipelineTests: XCTestCase {

    private func item(_ pid: Int32) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: "node x", elapsed: 0, tty: "??", kind: .node,
                    riskTier: .easy, cpuPercent: 0, rssKB: 0)
    }

    // MARK: - Request

    func testGlobalIgnores_areTheUnscopedSubstrings() {
        let request = ScanRequest(ignoreRules: [IgnoreRule(substring: "vite"),
                                                IgnoreRule(substring: "worker", pathPrefix: "~/code/proj"),
                                                IgnoreRule(substring: "jest")])
        XCTAssertEqual(request.globalIgnores, ["vite", "jest"])
    }

    func testRequestDefaults_matchTheCoreThreshold() {
        let request = ScanRequest()
        XCTAssertEqual(request.elapsedThreshold, ScanCore.defaultElapsedThreshold)
        XCTAssertTrue(request.globalIgnores.isEmpty)
        XCTAssertTrue(request.dismissedPIDs.isEmpty)
    }

    // MARK: - Pipeline tail

    func testFinish_appliesTheRequestsScopedRulesOnly() {
        // Two identical commands in different trees, plus one the *global* rule names:
        // global rules already ran inside `enumerate`, so the tail must not re-apply them.
        let worker = ProcessItem(pid: 10, ppid: 1, command: "node worker.js", elapsed: 0, tty: "??",
                                 kind: .node, riskTier: .easy, cpuPercent: 0, rssKB: 0)
        let elsewhere = ProcessItem(pid: 11, ppid: 1, command: "node worker.js", elapsed: 0, tty: "??",
                                    kind: .node, riskTier: .easy, cpuPercent: 0, rssKB: 0)
        let vite = ProcessItem(pid: 12, ppid: 1, command: "node vite", elapsed: 0, tty: "??",
                               kind: .node, riskTier: .easy, cpuPercent: 0, rssKB: 0)
        let cwds: [Int32: ProcessCwd] = [
            10: ProcessCwd(label: "proj", fullPath: "~/code/proj/app"),
            11: ProcessCwd(label: "other", fullPath: "~/code/other"),
            12: ProcessCwd(label: "proj", fullPath: "~/code/proj"),
        ]
        let request = ScanRequest(ignoreRules: [IgnoreRule(substring: "vite"),
                                                IgnoreRule(substring: "worker", pathPrefix: "~/code/proj")])
        XCTAssertEqual(ScanPipeline.finish([worker, elsewhere, vite], cwds: cwds, request: request).map(\.pid),
                       [11, 12])
    }

    // MARK: - Protected

    func testIsProtected_cwdUnderAProtectedTree() {
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "proj", fullPath: "~/code/proj/app")]
        XCTAssertTrue(ScanPipeline.isProtected(item(10), cwds: cwds, protectedProjects: ["~/code/proj"]))
    }

    func testIsProtected_siblingPrefixIsNotProtected() {
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "proj2", fullPath: "~/code/proj2")]
        XCTAssertFalse(ScanPipeline.isProtected(item(10), cwds: cwds, protectedProjects: ["~/code/proj"]))
    }

    func testIsProtected_unresolvedCwdIsNotProtected() {
        XCTAssertFalse(ScanPipeline.isProtected(item(10), cwds: [:], protectedProjects: ["~"]))
    }

    func testIsProtected_noProtectedProjects() {
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "proj", fullPath: "~/code/proj")]
        XCTAssertFalse(ScanPipeline.isProtected(item(10), cwds: cwds, protectedProjects: []))
    }

    // MARK: - Port-bound (PID-088)

    func testIsPortBound_rowListeningOnARegisteredPort() {
        XCTAssertTrue(ScanPipeline.isPortBound(item(10), listeningPorts: [10: [5173]], portScanUnavailable: false))
    }

    func testIsPortBound_aTreeMemberListeningCountsForTheRow() {
        let vite = item(11)
        let root = ProcessItem(pid: 10, ppid: 1, command: "npm run dev", elapsed: 0, tty: "??",
                               kind: .npm, riskTier: .moderate, cpuPercent: 0, rssKB: 0,
                               members: [vite])
        XCTAssertTrue(ScanPipeline.isPortBound(root, listeningPorts: [11: [5173]], portScanUnavailable: false))
    }

    func testIsPortBound_otherPIDsOrEmptyPortSetsAreNotBound() {
        XCTAssertFalse(ScanPipeline.isPortBound(item(10), listeningPorts: [:], portScanUnavailable: false))
        XCTAssertFalse(ScanPipeline.isPortBound(item(10), listeningPorts: [99: [5173]], portScanUnavailable: false))
        XCTAssertFalse(ScanPipeline.isPortBound(item(10), listeningPorts: [10: []], portScanUnavailable: false))
    }

    func testIsPortBound_unavailablePortScanCountsEveryRowAsBound() {
        // PID-090: an empty map from a failed lsof can't rule a listener out.
        XCTAssertTrue(ScanPipeline.isPortBound(item(10), listeningPorts: [:], portScanUnavailable: true))
    }

    // MARK: - Sweep

    func testIsSweepable_strayNotHighRiskUnprotectedAndKillable() {
        func sweepable(_ verdict: StrayVerdict = .sessionEnded, _ tier: RiskTier = .moderate,
                       protected: Bool = false, portBound: Bool = false,
                       _ killability: Killability = .killable) -> Bool {
            ScanPipeline.isSweepable(verdict: verdict, riskTier: tier, isProtected: protected,
                                     isPortBound: portBound, killability: killability)
        }
        XCTAssertTrue(sweepable())
        XCTAssertTrue(sweepable(.duplicate, .easy))
        XCTAssertTrue(sweepable(.idle))
        XCTAssertFalse(sweepable(.running), "in use")
        XCTAssertFalse(sweepable(.running, .easy), "the safe bucket alone no longer sweeps")
        XCTAssertFalse(sweepable(.sessionEnded, .high), "real dev infra stays a per-row call")
        XCTAssertFalse(sweepable(protected: true))
        XCTAssertFalse(sweepable(portBound: true), "a registered-port listener stays a per-row call (PID-088)")
        XCTAssertFalse(sweepable(.idle, .easy, portBound: true))
        XCTAssertFalse(sweepable(.sessionEnded, .moderate, .unkillable(owner: "root")))
        XCTAssertFalse(sweepable(.sessionEnded, .moderate, .respawner(manager: nil)))
    }
}
