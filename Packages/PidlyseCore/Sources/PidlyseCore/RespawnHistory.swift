import Foundation

/// Pure, in-memory record of *verified* kills and of the same logical process
/// coming back under a new PID (PID-62.2) — the signal behind "respawns; kill
/// won't stick".
///
/// A kill that `KillCore` verified as a real death arms a watch for that killed
/// identity, carrying its **command signature**. If a later scan surfaces the same
/// signature under a different identity while the watch is open, that's a respawn:
/// something restarted it (a parent supervisor, launchd, a Docker restart policy),
/// so killing it again would be a dead end. Watches are per killed identity
/// (PID-069): one armed kill can produce at most one respawn — the watch is
/// consumed on match — and one new process can answer at most one watch, so
/// same-signature kills made in separate clicks neither overwrite nor share a
/// verdict. Watches expire after `detectionWindow` so an unrelated reappearance
/// minutes later isn't misread.
///
/// Value-semantics and side-effect-free, mirroring `ScanHistory`: the app-side
/// `ScanEngine` owns the single mutable instance, arms it at the kill-completion
/// hook, and folds each scan into it. Session-only for the same reason (per
/// [[PID-62.1]] clarification #3) — respawn memory earned before a relaunch says
/// nothing about the current session, so a respawner re-earns its badge after one
/// kill attempt. Signal only: never touches `ScanCore.riskTier` / `bucket` / the
/// kill bar — `PID-62.3` and `PID-62.5` own what the user sees.
public struct RespawnHistory: Equatable {

    // MARK: - Tunable defaults

    /// How long after a verified kill a reappearance still counts as a respawn.
    /// Two default scan intervals (2 min each), so a supervisor that waits out a
    /// backoff before restarting is still caught.
    public static let defaultDetectionWindow: TimeInterval = 300

    // MARK: - Identity

    /// A process's *logical* identity — what stays the same when a supervisor
    /// restarts it under a fresh PID. Built from the command line plus the resolved
    /// working directory, so two `npm run dev` processes in different repos are
    /// distinct signatures.
    ///
    /// Normalization is deliberately conservative: over-stripping would collapse
    /// unrelated processes into one signature and badge an innocent row as a
    /// respawner. It lowercases, collapses whitespace, and drops only tokens that
    /// are *known* to change on every launch — per-launch temp paths, and the
    /// IPC-handle flags Chrome's helper processes carry (`--…-handle=`,
    /// `--…-client=`, `--…-fd=`). Everything else, ports included, is significant.
    public struct Signature: Hashable {
        /// The normalized signature text. Exposed for debugging and test assertions;
        /// equality is what callers actually consume.
        public let value: String

        public init(command: String, cwd: String? = nil) {
            let tokens = command.lowercased()
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
                .filter { !Signature.isVolatile($0) }
            let normalized = tokens.joined(separator: " ")
            guard let cwd, !cwd.isEmpty else {
                self.value = normalized
                return
            }
            self.value = "\(normalized) @ \(cwd.lowercased())"
        }

        /// Path fragments that only ever appear inside per-launch scratch directories.
        private static let volatilePathFragments = ["/var/folders/", "/tmp/"]
        /// Flag-name suffixes whose values are per-launch IPC handles (Chrome helpers).
        private static let volatileFlagSuffixes = ["-handle", "-client", "-fd"]

        private static func isVolatile(_ token: String) -> Bool {
            if volatilePathFragments.contains(where: token.contains) { return true }
            guard token.hasPrefix("--"), let equals = token.firstIndex(of: "=") else { return false }
            let name = token[token.startIndex..<equals]
            return volatileFlagSuffixes.contains(where: name.hasSuffix)
        }
    }

    /// One scanned process, reduced to what respawn detection needs.
    public struct Observation {
        public let pid: Int32
        public let startTime: ProcStartTime?
        public let signature: Signature

        public init(pid: Int32, startTime: ProcStartTime?, signature: Signature) {
            self.pid = pid
            self.startTime = startTime
            self.signature = signature
        }
    }

    /// A process instance: a PID plus its start time, so a recycled PID is a
    /// different identity.
    private struct Identity: Hashable {
        let pid: Int32
        let startTime: ProcStartTime?
    }

    /// An open watch: the identity we verified dead, its signature, and when the
    /// kill began.
    private struct Watch: Equatable {
        let identity: Identity
        let signature: Signature
        let killedAt: Date
    }

    // MARK: - State

    /// How long a watch stays open after a verified kill.
    public let detectionWindow: TimeInterval
    /// Open watches, one per killed identity (PID-069) — two same-signature kills
    /// each keep their own.
    private var watches: [Identity: Watch]
    /// Respawns detected this session, per signature. Grows only on a detected
    /// respawn, so it stays bounded by how many distinct things the user has killed
    /// and watched come back.
    private var counts: [Signature: Int]
    /// New processes that already answered a watch, with their start time, so a
    /// later scan can't hand the same comeback to a second kill. Pruned (on a fold
    /// with a watch open) once the start time falls outside `detectionWindow` — no
    /// open watch could match it.
    private var claimed: [Identity: Date]
    /// Killed identities whose watch was answered, with the kill time — the
    /// per-kill verdict `ScanEngine.kill` reads after its follow-up scan. Pruned
    /// with the same window.
    private var respawnedKills: [Identity: Date]

    public init(detectionWindow: TimeInterval = RespawnHistory.defaultDetectionWindow) {
        self.detectionWindow = detectionWindow
        self.watches = [:]
        self.counts = [:]
        self.claimed = [:]
        self.respawnedKills = [:]
    }

    // MARK: - Recording

    /// Arm a watch for a kill `KillCore` verified as a real death. Pure — returns a
    /// new value. Callers pass the killed process's scan-time identity so a
    /// same-identity reappearance (PID reuse) can be told apart from a respawn, and
    /// `now` as the moment the kill *began*: only a process started after it can be
    /// the killed one coming back (PID-62.5).
    public func recordingKill(signature: Signature,
                              pid: Int32,
                              startTime: ProcStartTime?,
                              at now: Date) -> RespawnHistory {
        var copy = self
        let identity = Identity(pid: pid, startTime: startTime)
        copy.watches[identity] = Watch(identity: identity, signature: signature, killedAt: now)
        return copy
    }

    /// Fold one scan's observations into a new history: every open watch is either
    /// expired (past `detectionWindow`), matched by a same-signature process under a
    /// *different* identity that started after the kill began and hasn't answered
    /// another watch — a respawn, counted and the watch consumed — or left open for
    /// the next scan. Pure; observations are only ever read, and with no watch open
    /// (the common case — nothing killed yet) the value is returned unchanged.
    public func recording(_ observations: [Observation], at now: Date) -> RespawnHistory {
        guard !watches.isEmpty else { return self }
        var copy = self
        let horizon = now.addingTimeInterval(-detectionWindow)
        copy.claimed = claimed.filter { $0.value >= horizon }
        copy.respawnedKills = respawnedKills.filter { $0.value >= horizon }
        // Newest kill first: a respawn can only answer a kill that began before it
        // started, so the newest watch has the fewest candidates and must choose
        // before an older watch takes its only one.
        for watch in watches.values.sorted(by: { $0.killedAt > $1.killedAt }) {
            guard watch.killedAt >= horizon else {
                copy.watches[watch.identity] = nil
                continue
            }
            // A same-signature process already running at kill time is a sibling
            // (two identical `node server.js` in one repo), not a respawn. One with
            // no start time can't be placed, so it doesn't count either.
            let respawn = observations.first {
                let identity = Identity(pid: $0.pid, startTime: $0.startTime)
                return $0.signature == watch.signature
                    && identity != watch.identity
                    && copy.claimed[identity] == nil
                    && $0.startTime.map { Self.date(of: $0) >= watch.killedAt } == true
            }
            if let respawn, let startTime = respawn.startTime {
                copy.claimed[Identity(pid: respawn.pid, startTime: startTime)] = Self.date(of: startTime)
                copy.respawnedKills[watch.identity] = watch.killedAt
                copy.counts[watch.signature, default: 0] += 1
                copy.watches[watch.identity] = nil
            }
        }
        return copy
    }

    /// A `ProcStartTime` (the kernel's `timeval`, since the epoch) as a `Date`.
    private static func date(of startTime: ProcStartTime) -> Date {
        Date(timeIntervalSince1970: TimeInterval(startTime.sec) + TimeInterval(startTime.usec) / 1_000_000)
    }

    // MARK: - Queries

    /// Whether the kill of this exact identity (armed via `recordingKill`) has been
    /// answered by a respawn — the per-kill verdict, so same-signature kills never
    /// read each other's comeback (PID-069). Valid for `detectionWindow` after the
    /// kill.
    public func didRespawn(pid: Int32, startTime: ProcStartTime?) -> Bool {
        respawnedKills[Identity(pid: pid, startTime: startTime)] != nil
    }

    /// How many times this signature has come back after a verified kill this session.
    public func respawnCount(for signature: Signature) -> Int {
        counts[signature] ?? 0
    }

    /// True once a signature has respawned at least once — the "kill won't stick"
    /// signal `PID-62.3` / `PID-62.5` surface.
    public func isRespawner(_ signature: Signature) -> Bool {
        respawnCount(for: signature) > 0
    }
}
