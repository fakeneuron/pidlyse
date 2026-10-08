import Foundation

/// A resolved working directory for one process: a short, readable `label` (the
/// enclosing git project, e.g. `bidviz` or `bidviz/frontend`) for the row, plus the
/// `~`-abbreviated `fullPath` for the hover tooltip. (PID-038)
public struct ProcessCwd: Equatable {
    /// Project-derived label shown as the row descriptor — the git repo name, plus the
    /// relative subpath when the process runs in a subfolder. Falls back to the leaf
    /// folder name when the cwd isn't inside a git repo.
    public let label: String
    /// The full `~`-abbreviated working directory, for the row's `.help` tooltip so the
    /// complete path is recoverable even when the label is short.
    public let fullPath: String
    /// The `~`-abbreviated git-root path (`~/code/bidviz`) when the cwd is inside a repo,
    /// else `nil`. The per-row 🔒 protect toggle seeds a protected-project prefix from
    /// this (falling back to `fullPath` outside a repo) so protecting one row shields the
    /// whole project tree. (PID-54.4)
    public let projectRoot: String?

    public init(label: String, fullPath: String, projectRoot: String? = nil) {
        self.label = label
        self.fullPath = fullPath
        self.projectRoot = projectRoot
    }
}

/// Resolves each scanned process's current working directory for the row descriptor
/// (PID-038): a bare `npm` / `node` row's executable name is redundant with its group
/// header, so the *project* it runs in (`bidviz`) is what identifies the owner.
///
/// Mirrors `PortRegistry`: a single bulk `lsof` shell-out feeds a pure, injectable
/// parser; the git-root walk and label derivation are likewise injectable/pure.
/// Resolved once per scan in `ScanEngine` and published as a `[Int32: ProcessCwd]` map
/// alongside `listeningPorts` / `containerOwners`. Empty when nothing resolves — the UI
/// degrades gracefully (falls back to the executable name), like the other hints.
public enum CwdResolver {

    /// Resolve cwd for `pids`, returning PID → `ProcessCwd` (project label + abbreviated
    /// full path). Empty when `pids` is empty or lsof yields nothing. `lsofOutput`,
    /// `home`, and `gitRootFinder` are injectable for tests.
    public static func processCwds(forPIDs pids: [Int32],
                                   lsofOutput: String? = nil,
                                   home: String = NSHomeDirectory(),
                                   gitRootFinder: (String) -> String? = findGitRoot) -> [Int32: ProcessCwd] {
        guard !pids.isEmpty else { return [:] }
        let output = lsofOutput ?? runLSOF(pids)
        return parseCwds(lsofOutput: output).mapValues { raw in
            let gitRoot = gitRootFinder(raw)
            return ProcessCwd(label: projectLabel(forCwd: raw, gitRoot: gitRoot),
                              fullPath: abbreviateHome(raw, home: home),
                              projectRoot: gitRoot.map { abbreviateHome($0, home: home) })
        }
    }

    /// True when `cwd` sits at or under `prefix` — a plain path-prefix containment used
    /// by both the protected-projects overlay and the cwd-scoped ignores (PID-54.4).
    /// Compare like-for-like: pass the same `~`-abbreviated form on each side (the
    /// scan's `ProcessCwd.fullPath` and the stored project prefix are both abbreviated).
    /// A trailing slash on `prefix` is tolerated; an empty `prefix` matches nothing, so a
    /// blank editor line can never protect/ignore everything by accident.
    public static func isUnderPrefix(_ cwd: String, _ prefix: String) -> Bool {
        let p = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
        guard !p.isEmpty else { return false }
        return cwd == p || cwd.hasPrefix(p + "/")
    }

    /// Parse `lsof -Fpn` field output into PID → cwd path. A `p<pid>` line opens a
    /// process set; the following `n<path>` line is its cwd (we request only the cwd
    /// descriptor via `-d cwd`, so there is exactly one `n` per process). Lines with an
    /// unparseable PID or empty path are skipped. Injectable for unit tests.
    public static func parseCwds(lsofOutput: String) -> [Int32: String] {
        var result = [Int32: String]()
        var currentPID: Int32?
        for line in lsofOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let s = String(line)
            guard let tag = s.first else { continue }
            let value = String(s.dropFirst())
            switch tag {
            case "p": currentPID = Int32(value)
            case "n": if let pid = currentPID, !value.isEmpty { result[pid] = value }
            default: break
            }
        }
        return result
    }

    /// Derive the short project label from an absolute cwd and its enclosing git root.
    /// In a repo: the repo folder name (`bidviz`), plus the relative subpath when the
    /// cwd is below the root (`bidviz/frontend`). Outside any repo: the leaf folder
    /// name — short and readable, never the full path. Pure; `gitRoot` is injectable.
    public static func projectLabel(forCwd cwd: String, gitRoot: String?) -> String {
        guard let root = gitRoot, !root.isEmpty else {
            let leaf = (cwd as NSString).lastPathComponent
            return leaf.isEmpty ? cwd : leaf
        }
        let repoName = (root as NSString).lastPathComponent
        if cwd == root { return repoName }
        if cwd.hasPrefix(root + "/") { return repoName + cwd.dropFirst(root.count) }
        return repoName
    }

    /// Collapse a leading home-directory prefix to `~` (`/Users/x/code/bidviz` →
    /// `~/code/bidviz`; the home dir itself → `~`). Paths outside `home`, and an empty
    /// `home`, are returned unchanged. Pure; `home` is injectable for tests.
    public static func abbreviateHome(_ path: String, home: String) -> String {
        guard !home.isEmpty else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    /// Walk up from `path` to the first ancestor containing a `.git` entry (dir or
    /// file — covers worktrees/submodules), returning that directory, or nil if none is
    /// found before `/`. Impure (filesystem), so it's injected into `processCwds`; a
    /// permission-denied / unreadable ancestor simply isn't a match (graceful degrade).
    public static func findGitRoot(_ path: String) -> String? {
        let fm = FileManager.default
        var dir = path
        while dir.hasPrefix("/") && dir != "/" {
            if fm.fileExists(atPath: dir + "/.git") { return dir }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break }
            dir = parent
        }
        return nil
    }

    // MARK: - lsof shell-out

    /// `-a` ANDs `-p` (the scanned PIDs) with `-d cwd` (the cwd descriptor only);
    /// `-Fpn` emits machine-parseable `p<pid>` / `n<path>` field lines.
    static func runLSOF(_ pids: [Int32]) -> String {
        let list = pids.map(String.init).joined(separator: ",")
        return Shell.run("/usr/sbin/lsof", ["-a", "-p", list, "-d", "cwd", "-Fpn"], timeout: Shell.Budget.lsof).output
    }
}
