import Foundation

/// Descriptive classification of a matched process. Drives the human-readable
/// label and feeds the risk tier. A process that matches no `ProcessKind` is
/// not a stray candidate and is excluded from scan results.
public enum ProcessKind: String, CaseIterable {
    case docker
    case uvicorn
    case npm
    case pytest
    case vitest
    case vite
    case jest
    case playwrightTest
    case playwrightMCP
    case chromeHelper
    case bun
    case node
    // Expanded built-in kinds (PID-54.2). Dev servers / build tools / local
    // infra, each slotted before the generic node/npm fallbacks in `detectKind`.
    case nextjs
    case astro
    case cargo
    case goRun
    case electron
    case llmServer
    case mcpServer
    // User-defined custom-rule match (PID-54.3). Sentinel kind — the friendly
    // per-rule label rides on `ProcessItem.customLabel`, not on this enum. Always
    // classified needsReview; excluded from the Settings "Scanned kinds" toggles.
    case custom

    /// Short, user-facing label shown in the popover row.
    public var label: String {
        switch self {
        case .docker:         return "Docker"
        case .uvicorn:        return "uvicorn"
        case .npm:            return "npm"
        case .pytest:         return "pytest"
        case .vitest:         return "vitest"
        case .vite:           return "Vite"
        case .jest:           return "Jest"
        case .playwrightTest: return "Playwright test"
        case .playwrightMCP:  return "playwright-mcp"
        case .chromeHelper:   return "Chrome (playwright-mcp)"
        case .bun:            return "Bun"
        case .node:           return "Node"
        case .nextjs:         return "Next.js"
        case .astro:          return "Astro"
        case .cargo:          return "cargo"
        case .goRun:          return "go run"
        case .electron:       return "Electron (dev)"
        case .llmServer:      return "LLM server"
        case .mcpServer:      return "MCP server"
        case .custom:         return "Custom rules"
        }
    }
}

/// How risky it is to kill a process. The display gradient (PID-003 may render
/// all three); the kill-action `Bucket` is derived from it.
public enum RiskTier {
    case easy       // obvious stray — orphaned, old, no terminal
    case moderate   // probably stray, but verify
    case high       // real dev infra (docker / uvicorn) or actively managed
}

/// The two kill-action buckets — the only classification the kill flow acts on.
/// Per CLAUDE.md: never auto-kill; `safe` items still require an explicit click.
public enum Bucket {
    case safe
    case needsReview
}

/// A process's start time, used as an identity token to detect PID reuse: if the
/// original process exits and the kernel recycles its PID for an unrelated process,
/// the start time differs. Captured at scan time (carried on `ProcessItem`) and
/// re-read at kill time so the kill path can confirm the PID still maps to the
/// *same* process. Lives here in `PidlyseCore` so `ProcessItem` can hold it; the
/// `sysctl` reader that produces it is `KillCore.startTime(of:)` (moved into the
/// core with the kill path, PID-57.2). (PID-18.3, PID-35.3)
public struct ProcStartTime: Equatable, Hashable {
    public let sec: Int
    public let usec: Int

    public init(sec: Int, usec: Int) {
        self.sec = sec
        self.usec = usec
    }
}

/// One process surfaced by the scan engine.
public struct ProcessItem: Identifiable {
    public let pid: Int32
    public let ppid: Int32
    /// Full command line (`ps` args column).
    public let command: String
    /// Elapsed run time.
    public let elapsed: TimeInterval
    /// Controlling terminal as reported by `ps` (`??` = none).
    public let tty: String
    public let kind: ProcessKind
    /// The friendly label from the matched user rule when `kind == .custom`;
    /// `nil` for built-in kinds. Feeds `displayLabel`. (PID-54.3)
    public let customLabel: String?
    public let riskTier: RiskTier
    /// CPU usage percentage from `ps pcpu` column.
    public let cpuPercent: Double
    /// Resident set size in KB from `ps rss` column.
    public let rssKB: Int
    /// Process start-time identity token captured at scan, or `nil` when not
    /// captured (tests, or a sysctl miss). The kill path re-verifies it before the
    /// initial SIGTERM to refuse killing a PID recycled since the scan. (PID-35.3)
    public let startTime: ProcStartTime?

    public init(pid: Int32, ppid: Int32, command: String, elapsed: TimeInterval,
                tty: String, kind: ProcessKind, riskTier: RiskTier,
                cpuPercent: Double, rssKB: Int, startTime: ProcStartTime? = nil,
                customLabel: String? = nil) {
        self.pid = pid
        self.ppid = ppid
        self.command = command
        self.elapsed = elapsed
        self.tty = tty
        self.kind = kind
        self.customLabel = customLabel
        self.riskTier = riskTier
        self.cpuPercent = cpuPercent
        self.rssKB = rssKB
        self.startTime = startTime
    }

    public var id: Int32 { pid }

    // MARK: - Derived signals (also surfaced by PID-008 "why is this here?")

    /// `safe` only for the easy tier; everything else needs explicit review.
    public var bucket: Bucket { riskTier == .easy ? .safe : .needsReview }

    /// User-facing label: the matched custom rule's friendly label when present,
    /// else the built-in `kind.label`. Display consumers (popover row descriptor,
    /// notifications, clean log) prefer this over `kind.label`. (PID-54.3)
    public var displayLabel: String { customLabel ?? kind.label }

    /// Compact display label shown in the popover row. Absolute-path executables
    /// format as `parentDir/executableName` (e.g. `bin/uvicorn`); bare-word
    /// commands show just the first token (e.g. `npm`).
    public var displayPath: String {
        let firstToken = command.split(separator: " ", maxSplits: 1)
            .first.map(String.init) ?? command
        guard firstToken.hasPrefix("/") else { return firstToken }
        let url = URL(fileURLWithPath: firstToken)
        let execName = url.lastPathComponent
        let parentName = url.deletingLastPathComponent().lastPathComponent
        guard !parentName.isEmpty, parentName != "/" else { return execName }
        return "\(parentName)/\(execName)"
    }

    /// True when a `ps` tty field denotes an attached controlling terminal.
    /// `??`, `?`, `-`, and empty all mean "no terminal". Static so callers
    /// (e.g. `ScanCore.makeItem`) can classify a raw field before a
    /// `ProcessItem` exists — single source of truth for the sentinel set.
    public static func isTTYAttached(_ tty: String) -> Bool {
        let t = tty.trimmingCharacters(in: .whitespaces)
        return !(t.isEmpty || t == "??" || t == "?" || t == "-")
    }

    /// True when the process has no controlling terminal — a stray indicator.
    public var hasTTY: Bool { Self.isTTYAttached(tty) }

    /// On macOS a process whose parent has died is reparented to launchd (pid 1).
    public var isOrphan: Bool { ppid == 1 }
}
