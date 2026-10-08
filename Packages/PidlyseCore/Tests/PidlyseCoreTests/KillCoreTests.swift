import XCTest
@testable import PidlyseCore

/// Tests for the PID-reuse guard added in PID-18.3: the SIGKILL fallback fires
/// only when the post-grace start time matches the pre-SIGTERM snapshot.
final class KillCoreTests: XCTestCase {

    private let a = ProcStartTime(sec: 1000, usec: 500)

    // MARK: - shouldEscalateToSIGKILL decision matrix

    // MARK: - Group outcome (PID-62.4)

    func testGroupOutcome_allGone_confirmed() {
        // Members that died with their root read as notKilled (already gone) — success.
        XCTAssertEqual(KillCore.groupOutcome(root: .confirmed, members: [.notKilled, .notKilled]), .confirmed)
        XCTAssertEqual(KillCore.groupOutcome(root: .confirmed, members: [.confirmed]), .confirmed)
    }

    func testGroupOutcome_rootAlreadyGone_memberKilled_confirmed() {
        XCTAssertEqual(KillCore.groupOutcome(root: .notKilled, members: [.confirmed]), .confirmed)
    }

    func testGroupOutcome_anySurvivor_survived() {
        XCTAssertEqual(KillCore.groupOutcome(root: .confirmed, members: [.notKilled, .survived]), .survived)
    }

    func testGroupOutcome_unkillableRoot_unkillable() {
        XCTAssertEqual(KillCore.groupOutcome(root: .unkillable, members: []), .unkillable)
    }

    func testGroupOutcome_foreignMemberAfterRootDied_survived() {
        // Root verified dead; a foreign-owned member lives on — not an unkillable *row*.
        XCTAssertEqual(KillCore.groupOutcome(root: .confirmed, members: [.unkillable]), .survived)
    }

    func testGroupOutcome_nothingOurs_notKilled() {
        XCTAssertEqual(KillCore.groupOutcome(root: .notKilled, members: [.notKilled]), .notKilled)
    }

    func testShouldEscalate_sameStartTime_escalates() {
        // PID still maps to the same process → SIGKILL is safe.
        let same = ProcStartTime(sec: 1000, usec: 500)
        XCTAssertTrue(KillCore.shouldEscalateToSIGKILL(snapshot: a, current: same))
    }

    func testShouldEscalate_differentStartTime_doesNotEscalate() {
        // PID recycled for a different process → must NOT SIGKILL the bystander.
        let reused = ProcStartTime(sec: 2000, usec: 0)
        XCTAssertFalse(KillCore.shouldEscalateToSIGKILL(snapshot: a, current: reused))
    }

    func testShouldEscalate_differingOnlyByMicroseconds_doesNotEscalate() {
        // Identity requires both fields equal; same second, different usec → mismatch.
        let nearMiss = ProcStartTime(sec: 1000, usec: 501)
        XCTAssertFalse(KillCore.shouldEscalateToSIGKILL(snapshot: a, current: nearMiss))
    }

    func testShouldEscalate_currentGone_doesNotEscalate() {
        // Process already exited during the grace period → nothing to kill.
        XCTAssertFalse(KillCore.shouldEscalateToSIGKILL(snapshot: a, current: nil))
    }

    func testShouldEscalate_snapshotMissing_doesNotEscalate() {
        // Identity never established at SIGTERM time → conservative: do not escalate.
        XCTAssertFalse(KillCore.shouldEscalateToSIGKILL(snapshot: nil, current: a))
    }

    func testShouldEscalate_bothMissing_doesNotEscalate() {
        XCTAssertFalse(KillCore.shouldEscalateToSIGKILL(snapshot: nil, current: nil))
    }

    // MARK: - startTime(of:) liveness reader

    func testStartTime_currentProcess_isNonNil() {
        XCTAssertNotNil(KillCore.startTime(of: getpid()))
    }

    func testStartTime_currentProcess_isStable() {
        // Reading the same live PID twice yields the same identity token.
        XCTAssertEqual(KillCore.startTime(of: getpid()), KillCore.startTime(of: getpid()))
    }

    func testStartTime_nonexistentPID_isNil() {
        // Beyond any assignable PID (kern.maxproc) → kernel returns no process.
        XCTAssertNil(KillCore.startTime(of: 2_000_000_000))
    }

    // MARK: - shouldSendSIGTERM decision matrix (PID-35.3 — pre-SIGTERM identity guard)

    func testShouldSendSIGTERM_sameStartTime_sends() {
        // PID still maps to the scanned process → safe to SIGTERM.
        let same = ProcStartTime(sec: 1000, usec: 500)
        XCTAssertTrue(KillCore.shouldSendSIGTERM(expected: a, current: same))
    }

    func testShouldSendSIGTERM_recycledPID_doesNotSend() {
        // PID recycled between scan and click → must NOT SIGTERM the bystander.
        let reused = ProcStartTime(sec: 2000, usec: 0)
        XCTAssertFalse(KillCore.shouldSendSIGTERM(expected: a, current: reused))
    }

    func testShouldSendSIGTERM_differingOnlyByMicroseconds_doesNotSend() {
        let nearMiss = ProcStartTime(sec: 1000, usec: 501)
        XCTAssertFalse(KillCore.shouldSendSIGTERM(expected: a, current: nearMiss))
    }

    func testShouldSendSIGTERM_processGoneSinceScan_doesNotSend() {
        // Had a scan-time token but the PID is gone now → nothing to kill.
        XCTAssertFalse(KillCore.shouldSendSIGTERM(expected: a, current: nil))
    }

    func testShouldSendSIGTERM_noScanToken_sends() {
        // No identity captured at scan → legacy fallback: send (never worse than
        // pre-PID-35.3, and a wiring miss can't silently no-op every kill).
        XCTAssertTrue(KillCore.shouldSendSIGTERM(expected: nil, current: a))
        XCTAssertTrue(KillCore.shouldSendSIGTERM(expected: nil, current: nil))
    }

    // MARK: - isStillRunning death check (PID-62.2 — post-SIGKILL verification)

    func testIsStillRunning_sameIdentity_stillRunning() {
        // Survived both signals under the same identity → the honest `.survived` path.
        let same = ProcStartTime(sec: 1000, usec: 500)
        XCTAssertTrue(KillCore.isStillRunning(snapshot: a, current: same, isZombie: false))
    }

    func testIsStillRunning_noProcessEntry_isDead() {
        XCTAssertFalse(KillCore.isStillRunning(snapshot: a, current: nil, isZombie: false))
    }

    func testIsStillRunning_recycledPID_isDead() {
        // A different start time means ours died and the PID was reassigned.
        let reused = ProcStartTime(sec: 2000, usec: 0)
        XCTAssertFalse(KillCore.isStillRunning(snapshot: a, current: reused, isZombie: false))
    }

    func testIsStillRunning_zombie_isDead() {
        // Exited but not yet reaped: the entry (and start time) persist, so without
        // the zombie check this identical-token case would read as a false survival.
        let same = ProcStartTime(sec: 1000, usec: 500)
        XCTAssertFalse(KillCore.isStillRunning(snapshot: a, current: same, isZombie: true))
    }

    func testIsStillRunning_noSnapshot_fallsBackToExistence() {
        // Identity never established (legacy no-token path) → existence is all we
        // can honestly assert, so a live entry counts as still running.
        XCTAssertTrue(KillCore.isStillRunning(snapshot: nil, current: a, isZombie: false))
        XCTAssertFalse(KillCore.isStillRunning(snapshot: nil, current: nil, isZombie: false))
        XCTAssertFalse(KillCore.isStillRunning(snapshot: nil, current: a, isZombie: true))
    }

    func testVerificationDelay_isShorterThanGracePeriod() {
        // A settle, not a second grace period — bulk sweeps must not slow down.
        XCTAssertLessThan(KillCore.verificationDelay, KillCore.gracePeriod)
        XCTAssertGreaterThan(KillCore.verificationDelay, 0)
    }
}
