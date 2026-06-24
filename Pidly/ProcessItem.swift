import Foundation

/// Descriptive classification of a matched process. Drives the human-readable
/// label and feeds the risk tier. A process that matches no `ProcessKind` is
/// not a stray candidate and is excluded from scan results.
enum ProcessKind: String, CaseIterable {
    case docker
    case uvicorn
    case npm
    case pytest
    case vitest
    case jest
    case playwrightTest
    case playwrightMCP
    case chromeHelper

    /// Short, user-facing label shown in the popover row.
    var label: String {
        switch self {
        case .docker:         return "Docker"
        case .uvicorn:        return "uvicorn"
        case .npm:            return "npm"
        case .pytest:         return "pytest"
        case .vitest:         return "vitest"
        case .jest:           return "Jest"
        case .playwrightTest: return "Playwright test"
        case .playwrightMCP:  return "playwright-mcp"
        case .chromeHelper:   return "Chrome (playwright-mcp)"
        }
    }
}

/// How risky it is to kill a process. The display gradient (PID-003 may render
/// all three); the kill-action `Bucket` is derived from it.
enum RiskTier {
    case easy       // obvious stray — orphaned, old, no terminal
    case moderate   // probably stray, but verify
    case high       // real dev infra (docker / uvicorn) or actively managed
}

/// The two kill-action buckets — the only classification the kill flow acts on.
/// Per CLAUDE.md: never auto-kill; `safe` items still require an explicit click.
enum Bucket {
    case safe
    case needsReview
}

/// One process surfaced by the scan engine.
struct ProcessItem: Identifiable {
    let pid: Int32
    let ppid: Int32
    /// Full command line (`ps` args column).
    let command: String
    /// Elapsed run time.
    let elapsed: TimeInterval
    /// Controlling terminal as reported by `ps` (`??` = none).
    let tty: String
    let kind: ProcessKind
    let riskTier: RiskTier

    var id: Int32 { pid }

    // MARK: - Derived signals (also surfaced by PID-008 "why is this here?")

    /// `safe` only for the easy tier; everything else needs explicit review.
    var bucket: Bucket { riskTier == .easy ? .safe : .needsReview }

    /// Compact display label shown in the popover row. Absolute-path executables
    /// format as `parentDir/executableName` (e.g. `bin/uvicorn`); bare-word
    /// commands show just the first token (e.g. `npm`).
    var displayPath: String {
        let firstToken = command.split(separator: " ", maxSplits: 1)
            .first.map(String.init) ?? command
        guard firstToken.hasPrefix("/") else { return firstToken }
        let url = URL(fileURLWithPath: firstToken)
        let execName = url.lastPathComponent
        let parentName = url.deletingLastPathComponent().lastPathComponent
        guard !parentName.isEmpty, parentName != "/" else { return execName }
        return "\(parentName)/\(execName)"
    }

    /// True when the process has no controlling terminal — a stray indicator.
    var hasTTY: Bool {
        let t = tty.trimmingCharacters(in: .whitespaces)
        return !(t.isEmpty || t == "??" || t == "?" || t == "-")
    }

    /// On macOS a process whose parent has died is reparented to launchd (pid 1).
    var isOrphan: Bool { ppid == 1 }
}
