import Foundation
import PidlyseCore

/// Shared app-side access to the Docker CLI: path resolution, a single
/// shell-out primitive, and a running-container listing. Owns the impure
/// `docker` invocations (extracted from `KillService`) so the kill path and the
/// upcoming container panel share one code path; the pure parsing lives in
/// `PidlyseCore.DockerCore` (mirrors the `ScanEngine` / `ScanCore` split).
enum DockerService {
    /// Path to the Docker CLI, or `nil` if not installed. A candidate is only
    /// accepted when its resolved binary passes the trust check below, so a trojan
    /// `docker` planted in a world-writable or foreign-owned location can't be
    /// exec'd on a docker-kill. (PID-35.3 / F2)
    static func cliPath() -> String? {
        let candidates = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]
        return candidates.first { isTrustedExecutable($0) }
    }

    /// Whether `path` is an executable whose resolved target is owned by root or
    /// the current user and is not world-writable — the impure half of the F2
    /// trust check (filesystem read; the policy is the pure `isTrustedOwnership`).
    ///
    /// Residual risk (accepted, see README §Security): `/usr/local/bin` is
    /// group-writable by `admin` on Intel by design, so a same-group attacker could
    /// still replace the binary there. Rejecting group-writable paths would silently
    /// break Docker detection on those machines, so it's deliberately out of scope.
    static func isTrustedExecutable(_ path: String) -> Bool {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: path) else { return false }
        let resolved = (path as NSString).resolvingSymlinksInPath
        guard let attrs = try? fm.attributesOfItem(atPath: resolved),
              let owner = attrs[.ownerAccountID] as? NSNumber,
              let perms = attrs[.posixPermissions] as? NSNumber else { return false }
        return isTrustedOwnership(ownerUID: owner.uint32Value,
                                  permissions: perms.uint16Value,
                                  currentUID: getuid())
    }

    /// Pure ownership/permission policy for the docker-binary trust check (the
    /// testable half of `isTrustedExecutable`). Trusted only when the binary is
    /// owned by root or the current user AND is not world-writable.
    static func isTrustedOwnership(ownerUID: UInt32, permissions: UInt16, currentUID: UInt32) -> Bool {
        let ownedByRootOrUser = (ownerUID == 0 || ownerUID == currentUID)
        let worldWritable = (permissions & 0o002) != 0
        return ownedByRootOrUser && !worldWritable
    }

    /// Whether the Docker CLI is available on this machine.
    static var isInstalled: Bool { cliPath() != nil }

    /// Shell out to the Docker CLI, reading stdout to EOF before `waitUntilExit`
    /// to prevent pipe-buffer deadlock. Returns stdout as UTF-8 and whether the
    /// process exited with status 0; `("", false)` when Docker is not installed
    /// or the launch fails.
    @discardableResult
    static func run(_ args: [String]) -> (output: String, ok: Bool) {
        guard let docker = cliPath() else { return ("", false) }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: docker)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        // Discard stderr via the null device, not an undrained Pipe(): we only ever
        // read stdout, so a captured-but-unread stderr pipe could fill its ~64 KB
        // buffer and wedge waitUntilExit() forever. /dev/null can't fill. (PID-35.2)
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return ("", false) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus == 0)
    }

    /// List running containers via `docker ps`. Returns an empty array when
    /// Docker is absent or the command fails.
    static func listContainers() -> [Container] {
        let result = run(["ps", "--format", DockerCore.psFormat])
        guard result.ok else { return [] }
        return DockerCore.parsePS(result.output)
    }

    /// Async wrapper over `listContainers()`: runs the (blocking) `docker ps`
    /// shell-out off the main queue and delivers the result on the main queue so
    /// SwiftUI can load/refresh the container list without freezing the popover.
    /// Keeps the shell-out inside `DockerService` (the view never touches
    /// `docker` or `DispatchQueue`), per CLAUDE.md.
    static func list(onComplete: @escaping ([Container]) -> Void) {
        DispatchQueue.global().async {
            let containers = listContainers()
            DispatchQueue.main.async { onComplete(containers) }
        }
    }

    // MARK: - Container actions (explicit-click only, per CLAUDE.md)

    /// Stop a running container via `docker stop` (Docker's own graceful
    /// SIGTERM → 10 s → SIGKILL). Runs off the main queue; `onComplete`
    /// delivers the refreshed running-container list on the main queue so the
    /// caller can re-render. Only ever invoked from an explicit user action —
    /// there is no auto-action path.
    static func stop(_ id: String, onComplete: @escaping ([Container]) -> Void = { _ in }) {
        performThenRefresh([["stop", id]], onComplete: onComplete)
    }

    /// Remove a container via `docker stop` then `docker rm`. The panel lists
    /// running containers only, so removal stops the container gracefully first
    /// (honoring the grace period — no force `-f`) before deleting it. Runs off
    /// the main queue; `onComplete` delivers the refreshed list on the main
    /// queue. Explicit-click only, per CLAUDE.md.
    static func remove(_ id: String, onComplete: @escaping ([Container]) -> Void = { _ in }) {
        performThenRefresh([["stop", id], ["rm", id]], onComplete: onComplete)
    }

    /// Run each docker invocation in sequence on a background queue, then
    /// re-list running containers and deliver the result on the main queue.
    private static func performThenRefresh(_ commands: [[String]],
                                           onComplete: @escaping ([Container]) -> Void) {
        DispatchQueue.global().async {
            for args in commands { run(args) }
            let containers = listContainers()
            DispatchQueue.main.async { onComplete(containers) }
        }
    }
}
