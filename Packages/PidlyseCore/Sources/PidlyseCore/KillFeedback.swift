import Foundation

/// Where one row's kill stands, as the user is told it (PID-62.5): in flight, or
/// the verified answer `KillCore` gave, refined by the post-kill respawn check.
/// Pure presentation vocabulary shared by the popover row, the Clean-all report,
/// and the CLI — so the same outcome reads the same everywhere.
public enum KillPhase: Equatable {
    /// Signals sent; waiting on the grace period and the death check.
    case killing
    /// Verified gone, and not back by the follow-up scan.
    case gone
    /// Verified gone, then back under a new PID by the follow-up scan.
    case respawned
    /// SIGTERM and SIGKILL delivered, still running under the same identity.
    case survived
    /// `EPERM` — owned by another user; nothing was signalled.
    case unkillable
    /// The identity guard refused: the PID was reused since the scan.
    case skipped

    /// The phase a verified `KillOutcome` starts in. `.respawned` is never produced
    /// here — only the follow-up scan can tell a `.gone` apart from it.
    public init(_ outcome: KillCore.KillOutcome) {
        switch outcome {
        case .confirmed:  self = .gone
        case .survived:   self = .survived
        case .unkillable: self = .unkillable
        case .notKilled:  self = .skipped
        }
    }

    /// Short row label, in place of the kill button.
    public var label: String {
        switch self {
        case .killing:    return "killing\u{2026}"
        case .gone:       return "gone"
        case .respawned:  return "respawned"
        case .survived:   return "didn\u{2019}t die"
        case .unkillable: return "can\u{2019}t kill"
        case .skipped:    return "skipped"
        }
    }

    /// One sentence on what the label means, for the row tooltip.
    public var detail: String {
        switch self {
        case .killing:    return "SIGTERM sent; SIGKILL follows after the 2 s grace period if needed."
        case .gone:       return "Verified gone."
        case .respawned:  return "Verified gone, but something started it again under a new PID."
        case .survived:   return "SIGTERM and SIGKILL were delivered, but the process is still running."
        case .unkillable: return "Owned by another user \u{2014} Pidlyse can\u{2019}t signal it."
        case .skipped:    return "The PID was reused since the scan, so nothing was signalled."
        }
    }

    /// Whether the row's process is no longer there — the row lingers only to show
    /// the result.
    public var isDeparted: Bool { self == .gone || self == .respawned }
}

/// The honest tally of a bulk kill (PID-62.5): what actually happened to each row,
/// not how many signals were sent. One source for the popover's Clean-all line,
/// the `pidlyse://clean` notification, the Shortcuts dialog, and CLI `clean`.
public struct KillReport: Equatable {
    public let requested: Int
    /// Verified gone and still gone at the follow-up check.
    public let gone: Int
    /// Verified gone, then back. Reported apart from `gone`: that kill didn't stick.
    public let respawned: Int
    public let survived: Int
    public let unkillable: Int
    public let skipped: Int
    /// Resident memory freed by the rows that stayed gone. A respawned process's
    /// memory came straight back, so it doesn't count.
    public let reclaimedKB: Int

    /// Tally `items` by their final phase. An item with no phase (or still
    /// `.killing`) counts toward `requested` only.
    public init(items: [ProcessItem], phases: [Int32: KillPhase]) {
        func count(_ phase: KillPhase) -> Int { items.filter { phases[$0.pid] == phase }.count }
        requested = items.count
        gone = count(.gone)
        respawned = count(.respawned)
        survived = count(.survived)
        unkillable = count(.unkillable)
        skipped = count(.skipped)
        reclaimedKB = items.filter { phases[$0.pid] == .gone }.reduce(0) { $0 + $1.rssKB }
    }

    /// `Cleaned 4 of 6`.
    public var headline: String { "Cleaned \(gone) of \(requested)" }

    /// Everything that didn't simply die, then the memory freed:
    /// `1 respawned · 1 didn’t die · 1.2 GB reclaimed`. Empty when there's nothing
    /// to add.
    public var details: String {
        var parts: [String] = []
        if respawned > 0 { parts.append("\(respawned) respawned") }
        if survived > 0 { parts.append("\(survived) \(KillPhase.survived.label)") }
        if unkillable > 0 { parts.append("\(unkillable) \(KillPhase.unkillable.label)") }
        if skipped > 0 { parts.append("\(skipped) skipped") }
        if reclaimedKB > 0 { parts.append("\(CLICore.formatRSS(kb: reclaimedKB)) reclaimed") }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// `headline` and `details` on one line.
    public var summaryLine: String {
        details.isEmpty ? headline : "\(headline) \u{00B7} \(details)"
    }
}
