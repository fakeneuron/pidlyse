import Foundation

/// Shared access to the Docker CLI: path resolution, a single shell-out
/// primitive, container listing, and the per-scan container-owner map. Owns the
/// impure `docker` invocations so the kill path (`KillCore`), the Containers
/// panel, and the cli-companion binary (PID-EPIC-57) share one code path; the
/// pure parsing lives in `DockerCore` (mirrors the `ScanEngine` / `ScanCore`
/// split). The SwiftUI-facing async wrappers (list / stats / restart / stop /
/// remove) stay app-side in `DockerService+Async.swift` so the core remains
/// run-loop-free.
public enum DockerService {
    /// Path to the Docker CLI, or `nil` if not installed. A candidate is only
    /// accepted when its resolved binary passes the trust check below, so a trojan
    /// `docker` planted in a world-writable or foreign-owned location can't be
    /// exec'd on a docker-kill. (PID-35.3 / F2)
    public static func cliPath() -> String? {
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
    public static func isTrustedExecutable(_ path: String) -> Bool {
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
    public static func isTrustedOwnership(ownerUID: UInt32, permissions: UInt16, currentUID: UInt32) -> Bool {
        let ownedByRootOrUser = (ownerUID == 0 || ownerUID == currentUID)
        let worldWritable = (permissions & 0o002) != 0
        return ownedByRootOrUser && !worldWritable
    }

    /// Whether the Docker CLI is available on this machine.
    public static var isInstalled: Bool { cliPath() != nil }

    /// Shell out to the Docker CLI via the shared `Shell` primitive. Returns
    /// stdout as UTF-8 and whether the process exited with status 0;
    /// `("", false)` when Docker is not installed or the launch fails. Owns the
    /// docker-specific *what* (path resolution); `Shell.run` owns the *how*.
    @discardableResult
    public static func run(_ args: [String]) -> (output: String, ok: Bool) {
        guard let docker = cliPath() else { return ("", false) }
        return Shell.run(docker, args)
    }

    /// List running containers via `docker ps`. Returns an empty array when
    /// Docker is absent or the command fails.
    public static func listContainers() -> [Container] {
        let result = run(["ps", "--format", DockerCore.psFormat])
        guard result.ok else { return [] }
        return DockerCore.parsePS(result.output)
    }

    /// Resolve every running container's host root PID to its name in a single
    /// bulk `docker inspect` over `docker ps -q`. Returns an empty map when
    /// Docker is absent or no containers run. Captured once per scan (see
    /// `ScanEngine.containerOwners`) so the kill path and the row-expansion
    /// ownership hint avoid a per-click inspect (retires the F9 `findContainerID`
    /// smell). The pure parse lives in `DockerCore.parseContainerOwners`.
    public static func containerOwners() -> [Int32: String] {
        let ids = run(["ps", "-q"]).output
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !ids.isEmpty else { return [:] }
        let result = run(["inspect", "--format", DockerCore.inspectOwnerFormat] + ids)
        guard result.ok else { return [:] }
        return DockerCore.parseContainerOwners(result.output)
    }
}
