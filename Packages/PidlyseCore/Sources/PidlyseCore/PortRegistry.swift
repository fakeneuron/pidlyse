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

    /// Compiled defaults merged with the user override file, computed once at startup.
    /// Port classification consults this set, not the raw `registeredPorts`.
    static let effectivePorts: Set<Int> = mergedPorts(userJSON: loadUserPortsJSON())

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
        var result = Set<Int32>()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if let pid = parsePIDAndPort(String(line)) {
                result.insert(pid)
            }
        }
        return result
    }

    /// Parse one line of `lsof -nPi -sTCP:LISTEN` output, returning the PID only if
    /// the line's port appears in `effectivePorts` (compiled defaults ∪ user override
    /// file). Returns nil for the header line or ports not in the registry.
    ///
    /// Expected column layout (fields split on whitespace):
    ///   COMMAND(0) PID(1) USER(2) FD(3) TYPE(4) DEVICE(5) SIZE/OFF(6) NODE(7) NAME(8) [(LISTEN)]
    /// NAME format: `*:3001`, `127.0.0.1:3001`, or `[::1]:3001`
    public static func parsePIDAndPort(_ line: String) -> Int32? {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 9 else { return nil }
        guard let pid = Int32(fields[1]) else { return nil }
        let name = String(fields[8])
        guard let colonIdx = name.lastIndex(of: ":") else { return nil }
        let portStr = String(name[name.index(after: colonIdx)...])
        guard let port = Int(portStr), effectivePorts.contains(port) else { return nil }
        return pid
    }

    // MARK: - lsof shell-out

    /// Shell out to an executable, reading stdout to EOF before `waitUntilExit`
    /// to prevent pipe-buffer deadlock. Returns stdout as UTF-8 ("" on failure).
    private static func runShell(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch { return "" }
    }

    static func runLSOF() -> String {
        runShell("/usr/sbin/lsof", ["-nPi", "-sTCP:LISTEN"])
    }
}
