import Foundation

/// Pure command grammar + output formatting for the `pidlyse` cli-companion
/// binary (PID-57.3). Lives in `PidlyseCore` — not the executable target — so
/// `PidlyseCoreTests` covers it via `swift test` (and `make test`); the executable's
/// `main.swift` owns the impure side (defaults
/// read, scan pipeline, signals, printing, exit codes). Mirrors the
/// `ScanEngine` ↔ `ScanCore` split.
public enum CLICore {

    // MARK: - Command grammar

    /// The `pidlyse` command surface. Hand-rolled parse over the argument
    /// vector — the repo stays zero-external-deps (PID-57.1 scoping).
    public enum Command: Equatable {
        case list(safeOnly: Bool)
        case clean
        case kill(pid: Int32)
        case help
    }

    /// Parse failures carry the offending token so the caller can print a
    /// one-line message ahead of the usage text.
    public enum ParseError: Equatable, Error {
        case unknownCommand(String)
        case unexpectedArgument(String)
        case missingPID
        case invalidPID(String)
    }

    /// Parse the argument vector (argv without the executable path). An empty
    /// vector reads as `help` — running bare `pidlyse` prints usage, it never
    /// scans or kills.
    public static func parse(_ args: [String]) -> Result<Command, ParseError> {
        guard let command = args.first else { return .success(.help) }
        let rest = Array(args.dropFirst())
        switch command {
        case "help", "--help", "-h":
            return .success(.help)
        case "list":
            if rest.isEmpty { return .success(.list(safeOnly: false)) }
            if rest == ["--safe"] { return .success(.list(safeOnly: true)) }
            return .failure(.unexpectedArgument(rest.first { $0 != "--safe" } ?? rest[0]))
        case "clean":
            guard rest.isEmpty else { return .failure(.unexpectedArgument(rest[0])) }
            return .success(.clean)
        case "kill":
            guard let token = rest.first else { return .failure(.missingPID) }
            guard rest.count == 1 else { return .failure(.unexpectedArgument(rest[1])) }
            guard let pid = Int32(token), pid > 0 else { return .failure(.invalidPID(token)) }
            return .success(.kill(pid: pid))
        default:
            return .failure(.unknownCommand(command))
        }
    }

    /// One-line human message for a parse failure.
    public static func message(for error: ParseError) -> String {
        switch error {
        case .unknownCommand(let token):    return "unknown command '\(token)'"
        case .unexpectedArgument(let token): return "unexpected argument '\(token)'"
        case .missingPID:                   return "kill requires a <pid> argument"
        case .invalidPID(let token):        return "'\(token)' is not a valid PID"
        }
    }

    public static let usage = """
        usage: pidlyse <command>

          list [--safe]   Scan and print stray candidates (--safe: safe bucket only)
          clean           Kill what the app's "Clean all" would sweep
                          (safe bucket minus protected projects and
                          processes owned by another user)
          kill <pid>      Kill one scanned candidate by PID (any bucket)
          help            Show this help

        Settings (threshold, ignores, custom rules, protected projects) are read
        from the Pidlyse app's preferences for full rule parity. Nothing is ever
        killed without an explicit clean/kill invocation.
        """

    // MARK: - Output formatting

    /// Compact elapsed-time display: `12s`, `45m`, `2h 13m`, `3d 4h`.
    public static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    /// Compact memory display from a `ps rss` KB figure: `512 KB`, `145 MB`, `1.4 GB`.
    public static func formatRSS(kb: Int) -> String {
        if kb >= 1_048_576 { return String(format: "%.1f GB", Double(kb) / 1_048_576) }
        if kb >= 1024 { return "\(kb / 1024) MB" }
        return "\(kb) KB"
    }

    /// Truncate `s` to at most `max` characters, appending `…` when trimmed.
    public static func truncate(_ s: String, max: Int) -> String {
        guard s.count > max, max > 1 else { return s }
        return s.prefix(max - 1) + "…"
    }

    /// Render the `pidlyse list` table: aligned columns computed from content,
    /// protected rows carry a 🔒 suffix in the BUCKET cell (excluded from
    /// `clean`, still individually killable — same semantics as the app's
    /// protected overlay, PID-54.4). Command lines are truncated for one-row
    /// readability; `pidlyse list` is a summary, not `ps`.
    public static func listTable(items: [ProcessItem],
                                 cwds: [Int32: ProcessCwd] = [:],
                                 protectedPIDs: Set<Int32> = [],
                                 commandMax: Int = 80) -> String {
        let header = ["PID", "BUCKET", "KIND", "AGE", "RAM", "PROJECT", "COMMAND"]
        let rows = items.map { item -> [String] in
            let bucket = item.bucket == .safe ? "safe" : "review"
            return [String(item.pid),
                    protectedPIDs.contains(item.pid) ? bucket + " 🔒" : bucket,
                    item.displayLabel,
                    formatElapsed(item.elapsed),
                    formatRSS(kb: item.rssKB),
                    cwds[item.pid]?.label ?? "—",
                    truncate(item.command, max: commandMax)]
        }
        let all = [header] + rows
        // Pad every column but the last to its widest cell.
        let widths = (0..<header.count - 1).map { col in all.map { $0[col].count }.max() ?? 0 }
        return all.map { row in
            let padded = row.enumerated().map { col, cell in
                col < widths.count ? pad(cell, to: widths[col]) : cell
            }
            return padded.joined(separator: "  ").trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n")
    }

    /// Right-pad to `width` by `Character` count — `String.padding(toLength:)`
    /// counts UTF-16 units, which clips a cell whose emoji (🔒) is two units.
    private static func pad(_ s: String, to width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
}
