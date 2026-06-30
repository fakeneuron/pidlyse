import Foundation

/// Hardcoded port table mirrored from the global CLAUDE.md localhost port registry.
/// Any process whose PID is listening on one of these ports is demoted to Needs Review
/// regardless of other classification criteria.
public enum PortRegistry {

    // MARK: - Port table (mirrored from ~/.claude/CLAUDE.md §"Localhost Port Registry")

    public static let registeredPorts: Set<Int> = [
        // InvisiPaw
        5182, 8001,
        5181, 8011,   // Docker canonical ports (5181 also bidviz — included once)
        // siteguy
        3001, 8003,
        // marscharts
        4000, 8000,
        // ADPpro
        5501,
        // bananapeel
        5173,
        // flowtron/viz
        5120,
        // stockshock
        5899, 8899, 8004,
        // bidviz
        8005,   // 5181 already covered above
        // fakeneuron
        3002,
        // spinalcord
        4321,
        // wandora
        5184, 8006,
        // delparte
        5183,
        // blastimage
        3003,
    ]

    // MARK: - User port overrides (PID-025)

    /// User-editable override file, keyed by project: `{"siteguy": [3001, 8003], …}`.
    /// Lives at `~/Library/Application Support/Pidlyse/ports.json`. Extend-only — its
    /// flattened ports are unioned with the compiled `registeredPorts`, so a user can
    /// add ports without recompiling but cannot remove a built-in. Decouples the manual
    /// CLAUDE.md ↔ `registeredPorts` sync burden for project-specific ports.
    static let userPortsFileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pidlyse/ports.json")
    }()

    /// Compiled defaults merged with the user override file, recomputed on each access so
    /// edits to `ports.json` take effect on the next scan without an app restart.
    static var effectivePorts: Set<Int> { mergedPorts(userJSON: loadUserPortsJSON()) }

    /// Pure merge: decode the keyed-by-project JSON, flatten its port lists, and union
    /// with the built-in set. Malformed or absent JSON yields the built-ins unchanged —
    /// the override file is advisory, never fatal to a scan. Injectable for unit tests.
    public static func mergedPorts(builtIn: Set<Int> = registeredPorts, userJSON: Data?) -> Set<Int> {
        guard let data = userJSON,
              let byProject = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else { return builtIn }
        return builtIn.union(byProject.values.flatMap { $0 })
    }

    /// Read the user override file if present. Returns nil when absent or unreadable.
    private static func loadUserPortsJSON() -> Data? {
        try? Data(contentsOf: userPortsFileURL)
    }

    // MARK: - Port listener detection

    /// PIDs currently listening on a registered port.
    /// `lsofOutput` is injectable so the pure pipeline can be unit-tested without shelling out.
    public static func listeningPIDs(lsofOutput: String? = nil) -> Set<Int32> {
        let output = lsofOutput ?? runLSOF()
        let ports = effectivePorts  // capture once per scan; effectivePorts re-reads disk each call
        var result = Set<Int32>()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if let pid = parsePIDAndPort(String(line), ports: ports) {
                result.insert(pid)
            }
        }
        return result
    }

    /// Parse one line of `lsof -nPi -sTCP:LISTEN` output, returning the PID only if
    /// the line's port appears in `ports` (defaults to the current `effectivePorts` when
    /// nil). Returns nil for the header line or ports not in the registry.
    public static func parsePIDAndPort(_ line: String, ports: Set<Int>? = nil) -> Int32? {
        parseListenerLine(line, ports: ports)?.pid
    }

    /// Parse one line of `lsof -nPi -sTCP:LISTEN` output into its (PID, registered port)
    /// pair, or nil for the header line / ports not in `ports` (defaults to the current
    /// `effectivePorts` when nil). Single source of truth for the listener-line column
    /// layout; `parsePIDAndPort` and `listeningPorts` both build on it.
    ///
    /// Expected column layout (fields split on whitespace):
    ///   COMMAND(0) PID(1) USER(2) FD(3) TYPE(4) DEVICE(5) SIZE/OFF(6) NODE(7) NAME(8) [(LISTEN)]
    /// NAME format: `*:3001`, `127.0.0.1:3001`, or `[::1]:3001`
    public static func parseListenerLine(_ line: String, ports: Set<Int>? = nil) -> (pid: Int32, port: Int)? {
        let activePorts = ports ?? effectivePorts
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 9 else { return nil }
        guard let pid = Int32(fields[1]) else { return nil }
        let name = String(fields[8])
        guard let colonIdx = name.lastIndex(of: ":") else { return nil }
        let portStr = String(name[name.index(after: colonIdx)...])
        guard let port = Int(portStr), activePorts.contains(port) else { return nil }
        return (pid, port)
    }

    /// Map each listening PID to the set of registered ports it listens on, mirroring
    /// `listeningPIDs`' injectable pipeline. A PID on multiple registered ports
    /// accumulates them; header lines and unregistered ports are skipped. Exposed for
    /// the per-row provenance hint (PID-036.3); the classifier still uses the bare PID
    /// set from `listeningPIDs` for demotion.
    public static func listeningPorts(lsofOutput: String? = nil) -> [Int32: Set<Int>] {
        let output = lsofOutput ?? runLSOF()
        let ports = effectivePorts  // capture once per scan; effectivePorts re-reads disk each call
        var result = [Int32: Set<Int>]()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if let match = parseListenerLine(String(line), ports: ports) {
                result[match.pid, default: []].insert(match.port)
            }
        }
        return result
    }

    // MARK: - lsof shell-out

    static func runLSOF() -> String {
        Shell.run("/usr/sbin/lsof", ["-nPi", "-sTCP:LISTEN"]).output
    }
}
