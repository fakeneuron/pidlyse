import XCTest
@testable import PidlyseCore

/// Tests for the PID-62.2 pure respawn cache: command-signature normalization,
/// the armed-watch lifecycle after a verified kill, and the detection window.
/// In-memory value type; the `ScanEngine` feed is not unit-tested (same split as
/// `ScanHistoryTests`).
final class RespawnHistoryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)
    /// Started long before the kill at `now`.
    private let t1 = ProcStartTime(sec: 1000, usec: 0)
    /// Started just after the kill at `now` — what a respawn looks like.
    private let t2 = ProcStartTime(sec: 1_000_001, usec: 0)
    /// Started after the re-kill at `now + 10`.
    private let t3 = ProcStartTime(sec: 1_000_012, usec: 0)

    private func sig(_ command: String, _ cwd: String? = nil) -> RespawnHistory.Signature {
        RespawnHistory.Signature(command: command, cwd: cwd)
    }

    private func obs(_ pid: Int32, _ start: ProcStartTime?,
                     _ signature: RespawnHistory.Signature) -> RespawnHistory.Observation {
        RespawnHistory.Observation(pid: pid, startTime: start, signature: signature)
    }

    // MARK: - Signature normalization

    func testSignature_collapsesWhitespaceAndCase() {
        XCTAssertEqual(sig("NPM   run    dev"), sig("npm run dev"))
    }

    func testSignature_cwdDistinguishesIdenticalCommands() {
        // The same dev-server command in two repos is two logical processes.
        XCTAssertNotEqual(sig("npm run dev", "~/code/bidviz"),
                          sig("npm run dev", "~/code/wandora"))
    }

    func testSignature_dropsPerLaunchTempPaths() {
        XCTAssertEqual(sig("node /var/folders/ab/T/xyz123/server.js --port 5173"),
                       sig("node --port 5173"))
    }

    func testSignature_dropsIPCHandleFlags() {
        // Chrome's helper flags carry a fresh handle every launch — the whole point
        // of the signature is that they don't defeat the match.
        XCTAssertEqual(sig("chrome --type=renderer --field-trial-handle=1,i,999 --seatbelt-client=42"),
                       sig("chrome --type=renderer --field-trial-handle=2,i,111 --seatbelt-client=7"))
    }

    func testSignature_keepsMeaningfulFlags() {
        // Conservative normalization: a port is significant, not volatile noise.
        XCTAssertNotEqual(sig("vite --port=5173"), sig("vite --port=5184"))
        XCTAssertNotEqual(sig("npm run dev"), sig("npm run build"))
    }

    // MARK: - Respawn detection

    func testRespawn_sameSignatureNewPID_isCounted() {
        let s = sig("npm run dev", "~/code/bidviz")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(5))
        XCTAssertTrue(h.isRespawner(s))
        XCTAssertEqual(h.respawnCount(for: s), 1)
    }

    func testRespawn_sameIdentityReappearing_isNotCounted() {
        // Same PID *and* start time is the process never having died — that is
        // `KillCore`'s `.survived`, not a respawn.
        let s = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(100, t1, s)], at: now.addingTimeInterval(5))
        XCTAssertFalse(h.isRespawner(s))
    }

    func testRespawn_unrelatedSignature_isNotCounted() {
        let killed = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: killed, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, sig("vitest run"))], at: now.addingTimeInterval(5))
        XCTAssertFalse(h.isRespawner(killed))
    }

    func testRespawn_watchIsConsumed_soOneKillCountsOnce() {
        // Without consuming the watch, every scan while the process lives would
        // re-count the same reappearance.
        let s = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(5))
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(10))
        XCTAssertEqual(h.respawnCount(for: s), 1)
    }

    func testRespawn_secondKillRearmsTheWatch() {
        let s = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(5))
        h = h.recordingKill(signature: s, pid: 200, startTime: t2, at: now.addingTimeInterval(10))
        h = h.recording([obs(300, t3, s)], at: now.addingTimeInterval(15))
        XCTAssertEqual(h.respawnCount(for: s), 2)
    }

    func testRespawn_siblingAlreadyRunningAtKillTime_isNotCounted() {
        // Two identical `node server.js` in one repo share a signature. Killing one
        // leaves the other listed under a different PID — that's a sibling that was
        // there all along, not the killed one coming back (PID-62.5).
        let s = sig("node server.js", "~/code/bidviz")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(101, t1, s)], at: now.addingTimeInterval(5))
        XCTAssertFalse(h.isRespawner(s))
        // The watch stays open: a genuine respawn later still counts.
        h = h.recording([obs(101, t1, s), obs(200, t2, s)], at: now.addingTimeInterval(10))
        XCTAssertEqual(h.respawnCount(for: s), 1)
    }

    func testRespawn_unknownStartTime_isNotCounted() {
        // Without a start time the process can't be placed after the kill, so it
        // can't be proven a respawn.
        let s = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, nil, s)], at: now.addingTimeInterval(5))
        XCTAssertFalse(h.isRespawner(s))
    }

    // MARK: - Per-identity watches (PID-069)

    func testRespawn_laterSameSignatureKill_doesNotOverwriteEarlierWatch() {
        // Two identical rows killed in separate clicks, both armed before any
        // follow-up scan. The earlier kill's comeback started before the later kill
        // began, so only the earlier watch can explain it — it must still be open.
        let s = sig("node server.js", "~/code/bidviz")
        let early = ProcStartTime(sec: 1_000_000, usec: 500_000)
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recordingKill(signature: s, pid: 101, startTime: t1, at: now.addingTimeInterval(1))
        h = h.recording([obs(200, early, s)], at: now.addingTimeInterval(3))
        XCTAssertTrue(h.didRespawn(pid: 100, startTime: t1))
        XCTAssertFalse(h.didRespawn(pid: 101, startTime: t1))
        XCTAssertEqual(h.respawnCount(for: s), 1)
    }

    func testRespawn_oneComebackAnswersOneKill_acrossSeparateScans() {
        // Kill A's follow-up scan claims the comeback. Kill B's own follow-up scan
        // sees the same process again and must not read it as B's respawn too.
        let s = sig("node server.js", "~/code/bidviz")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(2))
        h = h.recordingKill(signature: s, pid: 101, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(3))
        XCTAssertTrue(h.didRespawn(pid: 100, startTime: t1))
        XCTAssertFalse(h.didRespawn(pid: 101, startTime: t1))
        XCTAssertEqual(h.respawnCount(for: s), 1)
        // A second, distinct comeback still answers B.
        h = h.recording([obs(200, t2, s), obs(201, t3, s)], at: now.addingTimeInterval(20))
        XCTAssertTrue(h.didRespawn(pid: 101, startTime: t1))
        XCTAssertEqual(h.respawnCount(for: s), 2)
    }

    func testRespawn_twoComebacksInOneScan_answerBothKills() {
        let s = sig("node server.js", "~/code/bidviz")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recordingKill(signature: s, pid: 101, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s), obs(201, t2, s)], at: now.addingTimeInterval(3))
        XCTAssertTrue(h.didRespawn(pid: 100, startTime: t1))
        XCTAssertTrue(h.didRespawn(pid: 101, startTime: t1))
        XCTAssertEqual(h.respawnCount(for: s), 2)
    }

    func testDidRespawn_isIdentityScoped() {
        // A recycled PID (different start time) is not the kill that respawned.
        let s = sig("npm run dev")
        var h = RespawnHistory()
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(5))
        XCTAssertTrue(h.didRespawn(pid: 100, startTime: t1))
        XCTAssertFalse(h.didRespawn(pid: 100, startTime: t3))
    }

    // MARK: - Detection window

    func testRespawn_outsideDetectionWindow_isNotCounted() {
        let s = sig("npm run dev")
        var h = RespawnHistory(detectionWindow: 60)
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(61))
        XCTAssertFalse(h.isRespawner(s))
    }

    func testRespawn_atWindowBoundary_isCounted() {
        let s = sig("npm run dev")
        var h = RespawnHistory(detectionWindow: 60)
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(60))
        XCTAssertTrue(h.isRespawner(s))
    }

    func testRespawn_expiredWatchIsDropped_soALaterMatchDoesNotCount() {
        let s = sig("npm run dev")
        var h = RespawnHistory(detectionWindow: 60)
        h = h.recordingKill(signature: s, pid: 100, startTime: t1, at: now)
        h = h.recording([], at: now.addingTimeInterval(61))
        h = h.recording([obs(200, t2, s)], at: now.addingTimeInterval(62))
        XCTAssertFalse(h.isRespawner(s))
    }

    // MARK: - Baseline

    func testUnwatchedSignature_isNotARespawner() {
        let h = RespawnHistory()
        XCTAssertFalse(h.isRespawner(sig("npm run dev")))
        XCTAssertEqual(h.respawnCount(for: sig("npm run dev")), 0)
    }

    func testRecording_withNoWatches_isUnchanged() {
        let h = RespawnHistory()
        XCTAssertEqual(h.recording([obs(100, t1, sig("npm run dev"))], at: now), h)
    }

    func testDefaults_areExposed() {
        XCTAssertEqual(RespawnHistory.defaultDetectionWindow, 300)
        XCTAssertEqual(RespawnHistory().detectionWindow, RespawnHistory.defaultDetectionWindow)
    }
}
