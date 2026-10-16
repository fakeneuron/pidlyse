import XCTest
@testable import PidlyseCore

// MARK: - Killability overlay (PID-62.3)

/// The pure derivation behind "explanation replaces the kill button": which rows
/// Pidlyse can honestly offer to kill, and what it says about the ones it can't.
final class KillabilityTests: XCTestCase {

    private let me: uid_t = 501

    // MARK: - Group owner (PID-62.4)

    private func proc(_ pid: Int32, uid: uid_t?, members: [ProcessItem] = []) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: "node x", elapsed: 0, tty: "??", kind: .node,
                    riskTier: .high, cpuPercent: 0, rssKB: 0, uid: uid, members: members)
    }

    func testGroupOwnerUID_foreignMember_winsOverOwnedRoot() {
        let group = proc(10, uid: me, members: [proc(11, uid: me), proc(12, uid: 0)])
        XCTAssertEqual(Killability.groupOwnerUID(group, currentUID: me), 0)
    }

    func testGroupOwnerUID_allOwned_returnsRootUID() {
        let group = proc(10, uid: me, members: [proc(11, uid: nil)])
        XCTAssertEqual(Killability.groupOwnerUID(group, currentUID: me), me)
    }

    func testGroupOwnerUID_standaloneUnresolved_staysNil() {
        XCTAssertNil(Killability.groupOwnerUID(proc(10, uid: nil), currentUID: me))
    }

    // MARK: - Foreign-owner predicate

    func testForeignOwned_differentUID() {
        XCTAssertTrue(Killability.isForeignOwned(ownerUID: 0, currentUID: me))
        XCTAssertTrue(Killability.isForeignOwned(ownerUID: 502, currentUID: me))
    }

    func testForeignOwned_ownUID_isNotForeign() {
        XCTAssertFalse(Killability.isForeignOwned(ownerUID: me, currentUID: me))
    }

    func testForeignOwned_unknownUID_neverRemovesTheButton() {
        // `nil` means the uid wasn't resolved. Not knowing is not evidence, so the
        // permissive default holds — same posture as a missing identity token.
        XCTAssertFalse(Killability.isForeignOwned(ownerUID: nil, currentUID: me))
    }

    // MARK: - Owner labels

    func testOwnerLabel_rootIsNamed() {
        XCTAssertEqual(Killability.ownerLabel(uid: 0), "root")
    }

    func testOwnerLabel_otherUserCarriesTheRawUID() {
        XCTAssertEqual(Killability.ownerLabel(uid: 502), "another user (uid 502)")
    }

    func testOwnerLabel_unknownDegradesGracefully() {
        XCTAssertEqual(Killability.ownerLabel(uid: nil), "another user")
    }

    // MARK: - Respawn attribution

    func testManager_containerOwnerWins() {
        // A container's restart policy is the most specific answer available, so it
        // outranks the ancestor chain even when both resolve.
        XCTAssertEqual(Killability.manager(ancestors: ["node", "zsh"], containerOwner: "bidviz-db"),
                       "container bidviz-db")
    }

    func testManager_fallsBackToNearestAncestor() {
        XCTAssertEqual(Killability.manager(ancestors: ["node", "zsh", "launchd"], containerOwner: nil),
                       "node")
    }

    func testManager_orphanNamesLaunchd() {
        // A reparented orphan's nearest ancestor *is* launchd — the right answer, not
        // a fallback.
        XCTAssertEqual(Killability.manager(ancestors: ["launchd"], containerOwner: nil), "launchd")
    }

    func testManager_unresolvableIsNil() {
        XCTAssertNil(Killability.manager(ancestors: [], containerOwner: nil))
        XCTAssertNil(Killability.manager(ancestors: [], containerOwner: ""))
    }

    // MARK: - State derivation

    func testDerive_ordinaryRowStaysKillable() {
        XCTAssertEqual(Killability.derive(ownerUID: me, currentUID: me, killDenied: false,
                                          isRespawner: false, manager: nil),
                       .killable)
    }

    func testDerive_foreignOwnedBeforeAnyClick() {
        // The whole point of reading the uid at scan time: no dead-end click needed.
        XCTAssertEqual(Killability.derive(ownerUID: 0, currentUID: me, killDenied: false,
                                          isRespawner: false, manager: nil),
                       .unkillable(owner: "root"))
    }

    func testDerive_observedEPERMIsTheBackstop() {
        // uid never resolved, but an actual attempt came back EPERM — still unkillable,
        // with the label degrading to the generic form.
        XCTAssertEqual(Killability.derive(ownerUID: nil, currentUID: me, killDenied: true,
                                          isRespawner: false, manager: nil),
                       .unkillable(owner: "another user"))
    }

    func testDerive_respawner() {
        XCTAssertEqual(Killability.derive(ownerUID: me, currentUID: me, killDenied: false,
                                          isRespawner: true, manager: "node"),
                       .respawner(manager: "node"))
    }

    func testDerive_unkillableOutranksRespawner() {
        // Near-disjoint in practice (respawn detection requires a verified kill), but
        // the precedence is pinned so the derivation stays a total function.
        XCTAssertEqual(Killability.derive(ownerUID: 0, currentUID: me, killDenied: false,
                                          isRespawner: true, manager: "launchd"),
                       .unkillable(owner: "root"))
    }

    // MARK: - Explanation (single source for tooltip + inspector)

    func testExplanation_killableHasNothingToExplain() {
        XCTAssertNil(Killability.killable.explanation)
    }

    func testExplanation_unkillableNamesTheOwnerAndOurPosture() {
        XCTAssertEqual(Killability.unkillable(owner: "root").explanation,
                       "unkillable — owned by root; Pidlyse never escalates")
    }

    func testExplanation_respawnerNamesTheManager() {
        XCTAssertEqual(Killability.respawner(manager: "container bidviz-db").explanation,
                       "respawns — managed by container bidviz-db; kill won't stick")
    }

    func testExplanation_respawnerWithoutAManagerStillStatesTheBehavior() {
        // Attribution failed, but the actionable half — killing it again won't work —
        // is still true and still said.
        XCTAssertEqual(Killability.respawner(manager: nil).explanation,
                       "respawns after a kill — kill won't stick")
    }

    // MARK: - Scan plumbing

    func testUIDProviderReachesTheItem() {
        let line = " 4711     1    30:13 ??       0.1  12345  /usr/local/bin/npm run dev"
        let item = ScanCore.makeItem(from: line, elapsedThreshold: 60,
                                     uidProvider: { pid in pid == 4711 ? 0 : nil })
        XCTAssertEqual(item?.uid, 0)
        XCTAssertTrue(Killability.isForeignOwned(ownerUID: item?.uid, currentUID: me))
    }

    func testUIDIsNilWithoutAProvider() {
        // Every pre-PID-62.3 construction path: no provider, no uid, no behavior change.
        let line = " 4711     1    30:13 ??       0.1  12345  /usr/local/bin/npm run dev"
        XCTAssertNil(ScanCore.makeItem(from: line, elapsedThreshold: 60)?.uid)
    }

    // MARK: - Docker-stop route

    func testDockerContainerRootRoutesViaDockerStop() throws {
        let line = " 4711     1    30:13 ??       0.1  12345  /usr/local/bin/docker run redis"
        let item = try XCTUnwrap(ScanCore.makeItem(from: line, elapsedThreshold: 60))
        XCTAssertEqual(item.kind, .docker)
        XCTAssertTrue(KillCore.routesViaDockerStop(item, containerOwners: [4711: "redis"]))
        // Daemon/helper PIDs with no container owner fall through to signals.
        XCTAssertFalse(KillCore.routesViaDockerStop(item, containerOwners: [:]))
    }

    func testNonDockerKindNeverRoutesViaDockerStop() throws {
        let line = " 4711     1    30:13 ??       0.1  12345  /usr/local/bin/npm run dev"
        let item = try XCTUnwrap(ScanCore.makeItem(from: line, elapsedThreshold: 60))
        XCTAssertFalse(KillCore.routesViaDockerStop(item, containerOwners: [4711: "redis"]))
    }

    // MARK: - Row derivation (PID-079.6)

    private func row(_ pid: Int32, kind: ProcessKind, uid: uid_t?, members: [ProcessItem] = []) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: "x", elapsed: 0, tty: "??", kind: kind,
                    riskTier: .easy, cpuPercent: 0, rssKB: 0, uid: uid, members: members)
    }

    /// The CLI's call: a one-shot run has no session facts.
    private func derive(_ item: ProcessItem, owners: [Int32: String] = [:],
                        killDenied: Bool = false, isRespawner: Bool = false,
                        manager: String? = nil) -> Killability {
        Killability.derive(for: item, containerOwners: owners, currentUID: me,
                           killDenied: killDenied, isRespawner: isRespawner, manager: manager)
    }

    func testDeriveForRow_foreignOwned_isUnkillable() {
        XCTAssertEqual(derive(row(10, kind: .node, uid: 0)), .unkillable(owner: "root"))
    }

    func testDeriveForRow_dockerStopRoute_ignoresForeignOwner() {
        // `docker stop` needs no signal permission, so a root-owned container root
        // stays killable — the CLI sweep and the app's ✕ agree.
        let item = row(10, kind: .docker, uid: 0)
        XCTAssertEqual(derive(item, owners: [10: "redis"]), .killable)
        XCTAssertNotEqual(derive(item), .killable, "no container owner → signals → EPERM")
    }

    func testDeriveForRow_foreignGroupMember_isUnkillable() {
        let group = row(10, kind: .node, uid: me, members: [row(11, kind: .node, uid: 502)])
        XCTAssertNotEqual(derive(group), .killable)
    }

    func testDeriveForRow_passesSessionFactsThrough() {
        let item = row(10, kind: .node, uid: me)
        XCTAssertEqual(derive(item), .killable)
        XCTAssertEqual(derive(item, isRespawner: true, manager: "launchd"), .respawner(manager: "launchd"))
        XCTAssertNotEqual(derive(item, killDenied: true), .killable)
    }
}
