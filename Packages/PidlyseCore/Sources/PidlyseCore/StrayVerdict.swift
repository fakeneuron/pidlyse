import Foundation

/// Whether a scanned row looks forgotten, and why (PID-086.2). Turns Pidlyse from a
/// status locator (everything that matches a pattern) into a stray finder: the verdict
/// drives what the popover leads with, what the badge counts, and what "Clean all"
/// sweeps, while in-use processes fold away.
///
/// Not a third bucket: `riskTier` / `bucket` stay the kill-safety model underneath —
/// the sweep takes a stray only when it isn't high-risk or port-bound (`ScanPipeline.isSweepable`).
///
/// Pure. `derive` reads one whole scan, because a duplicate is only visible against
/// the other rows. The one fact a single scan can't hold — quiet CPU across recent
/// scans — is injected: the app feeds `ScanHistory`, the one-shot CLI a single sample.
public enum StrayVerdict: Equatable, CaseIterable {
    /// No terminal or app holds the process any more: its session is gone.
    case sessionEnded
    /// Another row runs the same command in the same directory and started later,
    /// and this one has no terminal of its own.
    case duplicate
    /// Quiet for hours with no terminal of its own.
    case idle
    /// In use — attached to a live session and not idle or duplicated.
    case running

    /// Whether the row is a likely stray (anything but `.running`).
    public var isStray: Bool { self != .running }

    /// User-facing reason, the sub-header the popover groups strays under.
    public var label: String {
        switch self {
        case .sessionEnded: return "Session ended"
        case .duplicate:    return "Duplicate"
        case .idle:         return "Idle"
        case .running:      return "Running"
        }
    }

    /// The one sentence saying why the row reads this way — the popover inspector's
    /// verdict line (PID-086.4).
    public var explanation: String {
        switch self {
        case .sessionEnded: return "No terminal or app holds it any more."
        case .duplicate:    return "A newer copy runs the same command in the same folder."
        case .idle:         return "Quiet for \(Int(Self.idleAge / 3600)) h or more, with no terminal of its own."
        case .running:      return "In use — attached to a live session."
        }
    }

    /// The order the popover's sub-headers and `pidlyse list` group rows in (PID-089):
    /// strays by reason, then running. Every case appears once; the popover, which
    /// lists strays only, drops `.running`.
    public static let displayOrder: [StrayVerdict] = [.sessionEnded, .idle, .duplicate, .running]

    /// How old a quiet, terminal-less process must be before it reads as idle.
    public static let idleAge: TimeInterval = 2 * 60 * 60

    // MARK: - Derivation

    /// One verdict per row of a scan, keyed by pid. Precedence: session ended, then
    /// duplicate, then idle — the most decisive fact names the row.
    ///
    /// - `cwds`: the scan's working directories; duplicates need a resolved one.
    /// - `processTable`: the whole-system table (`AncestryResolver`); with it empty,
    ///   only a direct orphan can read as session ended.
    /// - `isQuiet`: whether the row's CPU has stayed low (the app: `ScanHistory`).
    public static func derive(_ items: [ProcessItem],
                              cwds: [Int32: ProcessCwd],
                              processTable: [Int32: ProcessNode],
                              isQuiet: (ProcessItem) -> Bool) -> [Int32: StrayVerdict] {
        // The exact command + cwd. Not `RespawnHistory.Signature`: it strips per-launch
        // temp paths, so `node /tmp/a.js` and `node /tmp/b.js` would read as one job.
        let signatures = Dictionary(items.compactMap { item in
            cwds[item.pid].map { (item.pid, Twin(command: item.command, cwd: $0.fullPath)) }
        }, uniquingKeysWith: { first, _ in first })
        var verdicts: [Int32: StrayVerdict] = [:]
        for item in items {
            if isSessionEnded(item, processTable: processTable) {
                verdicts[item.pid] = .sessionEnded
            } else if hasNewerTwin(item, in: items, signatures: signatures) {
                verdicts[item.pid] = .duplicate
            } else if !isSessionTooling(item.kind), !item.hasTTY, item.elapsed >= idleAge, isQuiet(item) {
                verdicts[item.pid] = .idle
            } else {
                verdicts[item.pid] = .running
            }
        }
        return verdicts
    }

    /// What makes two rows copies of one another: the same command in the same cwd.
    struct Twin: Hashable {
        let command: String
        let cwd: String
    }

    /// Whether another row runs `item`'s command in `item`'s directory and started
    /// later — so `item` is the copy left behind. Needs a resolved cwd (two bare
    /// `npm run dev` could be any two projects), and a row with its own terminal is
    /// in use, the same rule idle follows.
    static func hasNewerTwin(_ item: ProcessItem, in items: [ProcessItem],
                             signatures: [Int32: Twin]) -> Bool {
        guard !isSessionTooling(item.kind), !item.hasTTY,
              let signature = signatures[item.pid] else { return false }
        return items.contains { other in
            other.pid != item.pid && other.elapsed < item.elapsed
                && !isSessionTooling(other.kind) && signatures[other.pid] == signature
        }
    }

    /// Whether nothing still holds `item`'s session: the row has no terminal, and its
    /// ancestors reach launchd without passing an **anchor** — a process with a
    /// terminal, or one inside an app bundle (Terminal, VS Code, the Claude app).
    /// Catches the plain orphan and the case `ppid == 1` misses: an agent session
    /// exits, its background shell is reparented to launchd, and the dev server keeps
    /// its own live parent under that shell. An ancestor missing from the table means
    /// "unknown", which never reads as ended.
    static func isSessionEnded(_ item: ProcessItem, processTable: [Int32: ProcessNode]) -> Bool {
        guard !item.hasTTY else { return false }
        var current = item.ppid
        var seen = Set<Int32>()
        while current > 1 {
            guard !seen.contains(current), let node = processTable[current] else { return false }
            if ProcessItem.isTTYAttached(node.tty) || node.isApp { return false }
            seen.insert(current)
            current = node.ppid
        }
        return current == 1
    }

    /// Kinds that live exactly as long as the agent session that started them: quiet
    /// by nature, and every session runs its own copy. Only a gone session makes one
    /// a stray, so they are never idle or duplicate.
    static func isSessionTooling(_ kind: ProcessKind) -> Bool {
        kind == .playwrightMCP || kind == .mcpServer || kind == .chromeHelper
    }
}
