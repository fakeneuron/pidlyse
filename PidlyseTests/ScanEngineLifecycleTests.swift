import XCTest
import PidlyseCore
@testable import Pidlyse

/// App-side `ScanEngine` lifecycle, driven through its injected seams (PID-078.3):
/// canned scan snapshots, a fake kill, an isolated defaults suite, a temp clean
/// log, and a short linger. Nothing here runs `ps` / `lsof` / `docker`, sends a
/// signal, or touches the user's settings or clean log.
final class ScanEngineLifecycleTests: XCTestCase {

    /// Serves canned snapshots to the engine's background scan, one per scan, then
    /// repeats the last. `hold()` blocks scans until `release()`, which keeps one in
    /// flight on purpose. Read from the scan queue and the test thread, so locked.
    private final class FakeSource: @unchecked Sendable {
        private let lock = NSLock()
        private var snapshots: [ScanSnapshot]
        private var gate: DispatchSemaphore?
        private var seen: [ScanRequest] = []
        /// Signalled each time a scan reaches the source.
        let started = DispatchSemaphore(value: 0)

        init(_ snapshots: ScanSnapshot...) {
            self.snapshots = snapshots
        }

        var requests: [ScanRequest] { lock.withLock { seen } }

        func hold() { lock.withLock { gate = DispatchSemaphore(value: 0) } }

        func release() {
            let held = lock.withLock { () -> DispatchSemaphore? in
                defer { gate = nil }
                return gate
            }
            held?.signal()
        }

        func scan(_ request: ScanRequest) -> ScanSnapshot {
            let (held, snapshot) = lock.withLock { () -> (DispatchSemaphore?, ScanSnapshot) in
                seen.append(request)
                return (gate, snapshots.count > 1 ? snapshots.removeFirst() : snapshots[0])
            }
            started.signal()
            held?.wait()
            return snapshot
        }
    }

    private var suiteNames: [String] = []
    private var logURL: URL!

    override func setUp() {
        super.setUp()
        logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pidlyse-lifecycle-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("clean-log.json")
    }

    override func tearDown() {
        suiteNames.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        try? FileManager.default.removeItem(at: logURL.deletingLastPathComponent())
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSuite() -> UserDefaults {
        let name = "pidlyse-lifecycle-\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeEngine(_ source: FakeSource,
                            defaults: UserDefaults? = nil,
                            killer: @escaping ScanEngine.Killer = { _, _, _ in XCTFail("unexpected kill") },
                            linger: TimeInterval = 0.2,
                            notifier: @escaping ScanEngine.Notifier = { _, _ in }) -> ScanEngine {
        ScanEngine(defaults: defaults ?? makeSuite(),
                   scanSource: source.scan,
                   killer: killer,
                   cleanLog: CleanLogStore(fileURL: logURL),
                   killFeedbackLinger: linger,
                   notifier: notifier)
    }

    private func item(_ pid: Int32, command: String = "node server.js", tier: RiskTier = .easy,
                      uid: uid_t? = getuid(), start: Int = 1) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: command, elapsed: 3600, tty: "??", kind: .node,
                    riskTier: tier, cpuPercent: 0, rssKB: 1024,
                    startTime: ProcStartTime(sec: start, usec: 0), uid: uid)
    }

    private func snapshot(_ items: [ProcessItem], cwds: [Int32: ProcessCwd] = [:]) -> ScanSnapshot {
        ScanSnapshot(items: items, cwds: cwds)
    }

    private func scanAndWait(_ engine: ScanEngine) {
        let done = expectation(description: "scan published")
        engine.scan { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    /// `DispatchQueue.main` work is not guaranteed to run inside `RunLoop.run`.
    /// Waiting on a block queued here drains everything already queued ahead of it.
    private func drainMain(for delay: TimeInterval) {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { drained.fulfill() }
        wait(for: [drained], timeout: delay + 1)
    }

    /// `CleanLogStore.record` appends on its own queue. Poll the injected file until
    /// the append lands, so a test neither races it nor ends with one still queued
    /// (which would recreate the temp directory after `tearDown`).
    private func waitForLoggedCleans(_ count: Int, timeout: TimeInterval = 3,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, CleanLogFile.load(from: logURL).count != count {
            drainMain(for: 0.02)
        }
        XCTAssertEqual(CleanLogFile.load(from: logURL).count, count, file: file, line: line)
    }

    // MARK: - Defaults suite

    func testSettingsPersistToInjectedSuite() {
        let suite = makeSuite()
        let standardBefore = UserDefaults.standard.stringArray(forKey: "ignoredNames")
        let engine = makeEngine(FakeSource(snapshot([])), defaults: suite)

        engine.ignoredNames = ["pidlyse-078-3-probe"]
        engine.protectedProjects = ["~/code/probe"]
        engine.elapsedThreshold = 600

        XCTAssertEqual(suite.stringArray(forKey: "ignoredNames"), ["pidlyse-078-3-probe"])
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "ignoredNames"), standardBefore)
        let reloaded = makeEngine(FakeSource(snapshot([])), defaults: suite)
        XCTAssertEqual(reloaded.ignoredNames, ["pidlyse-078-3-probe"])
        XCTAssertEqual(reloaded.protectedProjects, ["~/code/probe"])
        XCTAssertEqual(reloaded.elapsedThreshold, 600)
    }

    /// Every ignore line rides the request — global and cwd-scoped alike — and the
    /// shared core pipeline applies both (PID-079.6); the engine publishes the
    /// snapshot's items as they come back, minus only its own dismissals.
    func testScanRequestCarriesEveryIgnoreRule() {
        let source = FakeSource(snapshot([item(10), item(11)]))
        let engine = makeEngine(source)
        engine.ignoredNames = ["vite", "worker @ ~/code/proj"]

        scanAndWait(engine)

        XCTAssertEqual(source.requests.first?.ignoreRules,
                       [IgnoreRule(substring: "vite"), IgnoreRule(substring: "worker", pathPrefix: "~/code/proj")])
        XCTAssertEqual(engine.items.map(\.pid), [10, 11])
    }

    // MARK: - Rescan queueing

    func testScanDuringFlightQueuesExactlyOneFollowUp() {
        let source = FakeSource(snapshot([item(10)]), snapshot([item(11)]))
        source.hold()
        let engine = makeEngine(source)
        var published: [String: [Int32]] = [:]

        let first = expectation(description: "in-flight scan published")
        engine.scan {
            published["first"] = engine.items.map(\.pid)
            first.fulfill()
        }
        XCTAssertEqual(source.started.wait(timeout: .now() + 2), .success)

        let second = expectation(description: "follow-up scan published")
        engine.scan {
            published["second"] = engine.items.map(\.pid)
            second.fulfill()
        }
        engine.scan()
        XCTAssertTrue(engine.isScanning)
        XCTAssertEqual(source.requests.count, 1)

        source.release()
        wait(for: [first, second], timeout: 5, enforceOrder: true)

        // A completion waits for a scan that started after it was requested.
        XCTAssertEqual(published["first"], [10])
        XCTAssertEqual(published["second"], [11])
        drainMain(for: 0.1)
        XCTAssertEqual(source.requests.count, 2, "three requests in flight collapse to one follow-up")
        XCTAssertFalse(engine.isScanning)
    }

    // MARK: - Dismissal re-application

    func testDismissDuringFlightStaysHiddenUntilRescan() {
        let source = FakeSource(snapshot([item(10), item(11)]))
        source.hold()
        let engine = makeEngine(source)

        let first = expectation(description: "in-flight scan published")
        engine.scan { first.fulfill() }
        XCTAssertEqual(source.started.wait(timeout: .now() + 2), .success)
        // The in-flight request was built before this dismissal.
        engine.dismiss(10)
        XCTAssertEqual(source.requests.first?.dismissedPIDs, [])
        source.release()
        wait(for: [first], timeout: 5)
        XCTAssertEqual(engine.items.map(\.pid), [11])

        scanAndWait(engine)
        XCTAssertEqual(source.requests.last?.dismissedPIDs, [10])
        XCTAssertEqual(engine.items.map(\.pid), [11])

        // `rescan()` starts a scan; this request queues behind it, so its
        // completion fires once a scan with the cleared set has published.
        engine.rescan()
        scanAndWait(engine)
        XCTAssertEqual(source.requests.last?.dismissedPIDs, [])
        XCTAssertEqual(engine.items.map(\.pid), [10, 11])
    }

    // MARK: - Kill lifecycle

    func testKillPhasesLingerThenClear() {
        let gone = item(10)
        let stuck = item(11)
        let source = FakeSource(snapshot([gone, stuck]), snapshot([stuck]))
        var killed: [[Int32]] = []
        let engine = makeEngine(source, killer: { targets, _, done in
            killed.append(targets.map(\.pid))
            DispatchQueue.main.async { done([10: .confirmed, 11: .survived]) }
        })
        scanAndWait(engine)

        let reported = expectation(description: "kill reported")
        var report: KillReport?
        engine.kill([gone, stuck]) {
            report = $0
            reported.fulfill()
        }
        XCTAssertEqual(killed, [[10, 11]])
        XCTAssertEqual(engine.killPhase(for: gone), .killing)
        XCTAssertEqual(engine.killPhase(for: stuck), .killing)
        XCTAssertFalse(engine.isSweepable(gone), "a row mid-kill is out of the sweep")

        wait(for: [reported], timeout: 5)
        XCTAssertEqual(report?.gone, 1)
        XCTAssertEqual(report?.survived, 1)
        XCTAssertEqual(engine.killPhase(for: gone), .gone)
        XCTAssertEqual(engine.killPhase(for: stuck), .survived)
        XCTAssertEqual(engine.departedItems.keys.sorted(), [10], "only a verified death lingers as departed")
        XCTAssertEqual(engine.items.map(\.pid), [11], "the follow-up scan dropped the dead row")

        drainMain(for: 0.4)
        XCTAssertTrue(engine.killStatuses.isEmpty)
        XCTAssertTrue(engine.departedItems.isEmpty)
        // Only `.confirmed` is logged, and only to the injected log.
        waitForLoggedCleans(1)
    }

    func testNewerKillSurvivesOlderLingerClear() {
        let row = item(10)
        var pendingKills: [([Int32: KillService.KillOutcome]) -> Void] = []
        let engine = makeEngine(FakeSource(snapshot([row])), killer: { _, _, done in
            pendingKills.append(done)
        })
        scanAndWait(engine)

        let first = expectation(description: "first kill reported")
        engine.kill([row]) { _ in first.fulfill() }
        pendingKills.removeFirst()([10: .survived])
        wait(for: [first], timeout: 5)
        XCTAssertEqual(engine.killPhase(for: row), .survived)

        // A second kill lands before the first one's linger expires.
        let second = expectation(description: "second kill reported")
        engine.kill([row]) { _ in second.fulfill() }
        drainMain(for: 0.4)
        XCTAssertEqual(engine.killPhase(for: row), .killing, "the first kill's clear must not wipe the second")
        XCTAssertNil(engine.killPhase(for: item(10, start: 2)), "a recycled PID doesn't inherit the phase")

        pendingKills.removeFirst()([10: .survived])
        wait(for: [second], timeout: 5)
        XCTAssertEqual(engine.killPhase(for: row), .survived)
        drainMain(for: 0.4)
        XCTAssertNil(engine.killPhase(for: row))
    }

    /// A verified death back under a new PID by the follow-up scan reads
    /// `.respawned`, and its replacement leaves the sweep as a respawner.
    func testRespawnedKillLeavesTheSweep() {
        let row = item(10, start: 1)
        let comeback = item(20, start: Int(Date().timeIntervalSince1970) + 60)
        let source = FakeSource(snapshot([row]), snapshot([comeback]))
        let engine = makeEngine(source, killer: { _, _, done in
            DispatchQueue.main.async { done([10: .confirmed]) }
        })
        scanAndWait(engine)

        let reported = expectation(description: "kill reported")
        var report: KillReport?
        engine.kill([row]) {
            report = $0
            reported.fulfill()
        }
        wait(for: [reported], timeout: 5)

        XCTAssertEqual(report?.respawned, 1)
        XCTAssertEqual(report?.gone, 0)
        XCTAssertEqual(engine.killPhase(for: row), .respawned)
        XCTAssertTrue(engine.isRespawner(comeback))
        XCTAssertFalse(engine.isSweepable(comeback))
        XCTAssertTrue(engine.sweepableStrays.isEmpty)
        waitForLoggedCleans(1)
    }

    // MARK: - isSweepable fold

    func testIsSweepableFoldsVerdictProtectedOwnerAndKillPhase() {
        // `item` rows are orphans with no tty → session ended (PID-086.2).
        let plain = item(10)
        let locked = item(11)
        let foreign = item(12, uid: getuid() == 0 ? 1 : 0)
        let busy = item(13)
        let infra = item(14, tier: .high)
        let attached = ProcessItem(pid: 15, ppid: 500, command: "node server.js", elapsed: 3600,
                                   tty: "ttys001", kind: .node, riskTier: .moderate,
                                   cpuPercent: 0, rssKB: 1024, uid: getuid())
        let review = item(16, tier: .moderate)
        let source = FakeSource(snapshot([plain, locked, foreign, busy, infra, attached, review], cwds: [
            10: ProcessCwd(label: "free", fullPath: "~/code/free"),
            11: ProcessCwd(label: "proj", fullPath: "~/code/proj/app"),
        ]))
        var killed: [[Int32]] = []
        let engine = makeEngine(source, killer: { targets, _, _ in
            killed.append(targets.map(\.pid))
        })
        engine.protectedProjects = ["~/code/proj"]
        scanAndWait(engine)
        engine.kill([busy])

        XCTAssertEqual(engine.verdict(plain), .sessionEnded)
        XCTAssertEqual(engine.verdict(attached), .running)
        XCTAssertTrue(engine.isSweepable(plain))
        XCTAssertFalse(engine.isSweepable(locked), "protected project")
        XCTAssertFalse(engine.isSweepable(foreign), "owned by another user")
        XCTAssertFalse(engine.isSweepable(busy), "kill in flight")
        XCTAssertFalse(engine.isSweepable(infra), "high-risk strays stay a per-row call")
        XCTAssertFalse(engine.isSweepable(attached), "in use, not a stray")
        XCTAssertTrue(engine.isSweepable(review), "a needs-review stray is swept — the bucket no longer gates it")
        XCTAssertEqual(engine.sweepableStrays.map(\.pid), [10, 16])

        engine.cleanAllSafe()
        XCTAssertEqual(killed, [[13], [10, 16]], "Clean all kills exactly the sweepable stray set")
    }

    // MARK: - Strays-first popover feeds (PID-086.4)

    func testDepartedRowKeepsItsKillTimeVerdict() {
        // An orphan with no tty → session ended; once killed, no scan sees it again.
        let gone = item(10)
        let source = FakeSource(snapshot([gone]), snapshot([]))
        let engine = makeEngine(source, killer: { _, _, done in
            DispatchQueue.main.async { done([10: .confirmed]) }
        })
        scanAndWait(engine)
        XCTAssertEqual(engine.verdict(gone), .sessionEnded)

        let reported = expectation(description: "kill reported")
        engine.kill([gone]) { _ in reported.fulfill() }
        wait(for: [reported], timeout: 5)
        XCTAssertTrue(engine.items.isEmpty, "the follow-up scan dropped the dead row")
        XCTAssertEqual(engine.departedItems.keys.sorted(), [10])
        XCTAssertEqual(engine.verdict(gone), .sessionEnded, "lingers under Likely strays, not Running")

        drainMain(for: 0.4)
        XCTAssertEqual(engine.verdict(gone), .running, "forgotten with the departed row")
    }

    func testNotificationsAnnounceOnlyNewlyStrayRows() {
        let defaults = makeSuite()
        defaults.set(true, forKey: "notificationsEnabled")
        func attached(_ pid: Int32) -> ProcessItem {
            ProcessItem(pid: pid, ppid: 500, command: "node server.js", elapsed: 3600, tty: "ttys001",
                        kind: .node, riskTier: .moderate, cpuPercent: 0, rssKB: 1024, uid: getuid())
        }
        let source = FakeSource(
            snapshot([item(10), attached(15)]),
            // 15's session ended; 20 is a new stray; 21 is new but in use.
            snapshot([item(10), item(15), item(20, command: "node b.js"), attached(21)]),
            snapshot([item(10), item(15), item(20, command: "node b.js"), attached(21)]),
            // 20 flickers back to in use, then stray again.
            snapshot([item(10), item(15), attached(20), attached(21)]),
            snapshot([item(10), item(15), item(20, command: "node b.js"), attached(21)])
        )
        var posted: [(title: String, body: String)] = []
        let engine = makeEngine(source, defaults: defaults, notifier: { posted.append(($0, $1)) })

        scanAndWait(engine)
        XCTAssertTrue(posted.isEmpty, "the first scan sets the baseline")
        XCTAssertEqual(engine.strayArrivals, 1, "the first scan's strays pulse the icon once")

        scanAndWait(engine)
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted.first?.title, "2 new likely strays", "15 turned stray, 20 is new; 21 is running")
        XCTAssertEqual(engine.strayArrivals, 2)

        scanAndWait(engine)
        scanAndWait(engine)
        scanAndWait(engine)
        XCTAssertEqual(posted.count, 1, "an unchanged or flickering stray set announces nothing")
        XCTAssertEqual(engine.strayArrivals, 2, "nor pulses the icon")
    }
}
