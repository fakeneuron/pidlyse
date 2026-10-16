import Foundation

/// One node in the full system process table: a parent pid plus a compact,
/// human-readable label for the executable. Built for the inspector's parent-chain
/// hint (PID-52.2), which walks ancestors all the way to launchd — including the
/// non-stray processes (shells, `login`, launchd) that `ScanCore.parentCommand`
/// deliberately omits (it resolves only within the scanned stray set).
public struct ProcessNode: Equatable {
    /// Parent process id (`ps ppid`).
    public let ppid: Int32
    /// Compact executable label — the last path component of `ps comm`.
    public let label: String
    /// Controlling terminal as reported by `ps` (`??` = none). With `isApp`, what
    /// tells the stray verdict a live session still holds a process (PID-086.2).
    public let tty: String
    /// True when the executable lives inside a `.app/` bundle (Terminal, VS Code,
    /// the Claude desktop app) — a GUI host that keeps its children's session alive.
    public let isApp: Bool

    public init(ppid: Int32, label: String, tty: String = "??", isApp: Bool = false) {
        self.ppid = ppid
        self.label = label
        self.tty = tty
        self.isApp = isApp
    }
}

/// Resolves a process's complete ancestor chain up to launchd (pid 1) for the
/// inspector's "child of …" hint (PID-52.2). Unlike `ScanCore.parentCommand`
/// (scanned strays only), this walks the *whole* system process table, so it can
/// name shells / `login` / launchd that were never stray candidates.
///
/// Mirrors `PortRegistry` / `CwdResolver`: a single bulk `ps` shell-out feeds a
/// pure, injectable parser; the chain walk is pure. Resolved once per scan in
/// `ScanEngine` and published as a `[Int32: ProcessNode]` map. Empty when nothing
/// resolves — the UI degrades gracefully (no chain line), like the other hints.
public enum AncestryResolver {

    /// Build the full pid → `ProcessNode` table from `ps` output. `psOutput` is
    /// injectable for tests; the live call uses `ps -axo pid=,ppid=,tty=,comm=` — the
    /// whole table (not just strays), on the pinned `ps` surface (no new binary,
    /// per PID-049).
    public static func processTable(psOutput: String? = nil) -> [Int32: ProcessNode] {
        let output = psOutput ?? runPS()
        var table = [Int32: ProcessNode]()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let parsed = parseLine(String(line)) else { continue }
            table[parsed.pid] = parsed.node
        }
        return table
    }

    /// Parse one `pid ppid tty comm` line: the first three whitespace-delimited fields
    /// are pid + ppid + tty; everything after is `comm` (an executable path that may
    /// itself contain spaces, e.g. `.../Code Helper`), compacted to its last path
    /// component, with `isApp` read from the full path first.
    /// Returns nil for an unparseable pid/ppid or an empty comm.
    public static func parseLine(_ line: String) -> (pid: Int32, node: ProcessNode)? {
        var remainder = Substring(line)
        var fields: [Substring] = []
        for _ in 0..<3 {
            while let c = remainder.first, c == " " || c == "\t" { remainder = remainder.dropFirst() }
            guard let space = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            fields.append(remainder[..<space])
            remainder = remainder[space...]
        }
        let comm = remainder.trimmingCharacters(in: .whitespaces)
        guard let pid = Int32(fields[0]), let ppid = Int32(fields[1]), !comm.isEmpty else { return nil }
        return (pid, ProcessNode(ppid: ppid, label: compactLabel(comm), tty: String(fields[2]),
                                 isApp: comm.contains(".app/")))
    }

    /// Compact an executable path to a readable leaf (`/bin/zsh` → `zsh`,
    /// `/sbin/launchd` → `launchd`). A bare name passes through unchanged.
    public static func compactLabel(_ comm: String) -> String {
        let leaf = (comm as NSString).lastPathComponent
        return leaf.isEmpty ? comm : leaf
    }

    /// Walk ancestors from `ppid` up to launchd, returning labels ordered
    /// nearest-parent → launchd. Stops at pid ≤ 0 (launchd's ppid), a missing table
    /// entry, or a revisited pid (cycle guard — a real table is acyclic, but the walk
    /// stays bounded regardless).
    public static func ancestorChain(ofPPID ppid: Int32, in table: [Int32: ProcessNode]) -> [String] {
        var chain = [String]()
        var current = ppid
        var seen = Set<Int32>()
        while current > 0, !seen.contains(current), let node = table[current] {
            seen.insert(current)
            chain.append(node.label)
            current = node.ppid
        }
        return chain
    }

    // MARK: - ps shell-out

    /// `-axo pid=,ppid=,tty=,comm=` emits the whole process table (headerless) as
    /// `pid ppid tty comm` — enough to walk any process's ancestry to launchd and see
    /// which ancestors still hold a terminal (PID-086.2).
    static func runPS() -> String {
        Shell.run("/bin/ps", ["-axo", "pid=,ppid=,tty=,comm="], timeout: Shell.Budget.ps).output
    }
}
