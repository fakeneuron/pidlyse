import Foundation

/// Whether Pidlyse can honestly offer to kill a process — and, when it can't, why
/// not and in words the user can act on (PID-62.3).
///
/// The epic's first principle is that a kill affordance is a promise: the ✕ button
/// appears only where we reasonably believe the process will die *and stay dead*.
/// Two states break that promise, and each now says so instead of offering a
/// dead-end button:
///
/// - **unkillable** — the process belongs to another user (the root Docker daemon
///   is the common case). Pidlyse runs unprivileged and never escalates, so every
///   signal it could send hits `EPERM`. Known two ways: the owning uid read at scan
///   time (before any click), and `KillCore.KillOutcome.unkillable` observed from an
///   actual attempt (the backstop, for anything the uid read missed).
/// - **respawner** — the process died, and `RespawnHistory` (PID-62.2) then saw its
///   command signature come back under a new PID. Something restarts it, so killing
///   it again is a dead end; the honest move is to name what restarts it.
///
/// This is an **overlay**, never a third bucket: `riskTier` and `bucket` are
/// untouched, and affected rows stay listed where they were — the same shape the
/// 🔒 protected-projects overlay took (PID-54.4).
///
/// Pure and side-effect-free. `ScanEngine` supplies the impure inputs (the scan's
/// uid, the session's observed `EPERM`s, the respawn query, the ancestor chain);
/// `MenuBarView` renders the result.
public enum Killability: Equatable {
    /// Nothing stands in the way of a kill — the row keeps its ✕ button.
    case killable
    /// Owned by another user; `owner` is a human-readable label for that owner.
    case unkillable(owner: String)
    /// Verified dead at least once this session, then seen again under a new PID.
    /// `manager` names whatever restarts it, or is `nil` when it can't be resolved.
    case respawner(manager: String?)

    // MARK: - Derivation

    /// Fold the four facts about a process into its killability state.
    ///
    /// `ownerUID` is the scan-time owner (`nil` = not resolved), `currentUID` the user
    /// Pidlyse runs as, `killDenied` whether an actual attempt this session came back
    /// `EPERM`, and `isRespawner` / `manager` the respawn signal and its attribution.
    ///
    /// Unkillable outranks respawner. The two are near-disjoint in practice — respawn
    /// detection requires a *verified kill*, which a foreign-owned process never gets —
    /// but fixing the order keeps this a total function, and "we never got to kill it"
    /// is the more fundamental truth about the row.
    public static func derive(ownerUID: uid_t?,
                              currentUID: uid_t,
                              killDenied: Bool,
                              isRespawner: Bool,
                              manager: String?) -> Killability {
        if killDenied || isForeignOwned(ownerUID: ownerUID, currentUID: currentUID) {
            return .unkillable(owner: ownerLabel(uid: ownerUID))
        }
        return isRespawner ? .respawner(manager: manager) : .killable
    }

    /// Whether a process belongs to someone other than the user Pidlyse runs as — the
    /// pre-click half of the unkillable signal. An unresolved uid means "unknown", and
    /// the honest response to not knowing is to leave the affordance alone (the same
    /// permissive default `startTime == nil` gets in the PID-35.3 identity guard).
    public static func isForeignOwned(ownerUID: uid_t?, currentUID: uid_t) -> Bool {
        guard let ownerUID else { return false }
        return ownerUID != currentUID
    }

    /// The owner uid that decides a row's killability. For a group row
    /// (`ScanCore.collapseTrees`, PID-62.4) that's the first foreign-owned member, if
    /// any: part of the tree would survive the group kill, so the row can't honestly
    /// offer one. Otherwise it's the root's uid (still `nil` when unresolved).
    public static func groupOwnerUID(_ item: ProcessItem, currentUID: uid_t) -> uid_t? {
        let foreign = ([item] + item.members).first {
            isForeignOwned(ownerUID: $0.uid, currentUID: currentUID)
        }
        return foreign?.uid ?? item.uid
    }

    /// Human-readable owner for the explanation sentence. Root is worth naming
    /// outright — it's the case users actually hit (Docker, system daemons); any other
    /// foreign uid is rare enough that the raw number is the most honest thing to show.
    public static func ownerLabel(uid: uid_t?) -> String {
        guard let uid else { return "another user" }
        return uid == 0 ? "root" : "another user (uid \(uid))"
    }

    /// Who to blame for a respawn. A container owner is the most specific answer
    /// available (its restart policy is doing this); otherwise the nearest ancestor
    /// from `AncestryResolver.ancestorChain` — which for an orphan is `launchd`,
    /// exactly the right answer. `nil` when neither resolves, and the explanation
    /// degrades to naming the behavior without the culprit.
    public static func manager(ancestors: [String], containerOwner: String?) -> String? {
        if let containerOwner, !containerOwner.isEmpty { return "container \(containerOwner)" }
        return ancestors.first
    }

    // MARK: - Presentation

    /// The one sentence explaining this state, or `nil` for `.killable` (nothing to
    /// explain — the row renders no extra line). Single source for both surfaces that
    /// show it, the row badge's tooltip and the ⓘ inspector line, so the two can't
    /// drift apart.
    public var explanation: String? {
        switch self {
        case .killable:
            return nil
        case .unkillable(let owner):
            return "unkillable — owned by \(owner); Pidlyse never escalates"
        case .respawner(let manager):
            guard let manager else { return "respawns after a kill — kill won't stick" }
            return "respawns — managed by \(manager); kill won't stick"
        }
    }
}
