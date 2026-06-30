import Foundation

/// Shared subprocess primitive for the whole codebase. Spawns `path` with
/// `args`, reads stdout to EOF *before* `waitUntilExit` to prevent pipe-buffer
/// deadlock, and reports whether the process exited 0.
///
/// Owns the *how* of shelling out (the `Process`/`Pipe` dance); callers own the
/// *what* (which binary, which args, how to parse). `ScanCore.runPS`,
/// `PortRegistry.runLSOF`, and `CwdResolver.runLSOF` take `.output` and ignore
/// status; the app-side `DockerService.run` keeps its `cliPath()` guard and
/// returns the full tuple. Consolidated here by PID-042 (the cleanup PID-35.2
/// deferred); single shared body across all four prior copies.
public enum Shell {
    /// Returns stdout as UTF-8 (`""` on launch failure) and whether the process
    /// exited with status 0 (`false` on launch failure).
    @discardableResult
    public static func run(_ path: String, _ args: [String]) -> (output: String, ok: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        // Discard stderr via the null device, not an undrained Pipe(): we only ever
        // read stdout, so a captured-but-unread stderr pipe could fill its ~64 KB
        // buffer and wedge waitUntilExit() forever. /dev/null can't fill. (PID-35.2)
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus == 0)
        } catch { return ("", false) }
    }
}
