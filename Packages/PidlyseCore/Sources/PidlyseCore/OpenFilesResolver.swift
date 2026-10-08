import Foundation

/// One open file (or socket) held by a process, for the inspector's on-demand
/// open-files list (PID-52.3). `name` is the file path (home-abbreviated to `~`)
/// or the socket's `lsof` name (`127.0.0.1:5432`); `isSocket` distinguishes the
/// two so the composer skips home-abbreviation on socket names.
public struct OpenFile: Equatable {
    /// Display string: a `~`-abbreviated file path, or a socket's raw `lsof` name.
    public let name: String
    /// True for network / unix-domain sockets (`IPv4` / `IPv6` / `unix`); false for
    /// regular files (`REG`).
    public let isSocket: Bool

    public init(name: String, isSocket: Bool) {
        self.name = name
        self.isSocket = isSocket
    }
}

/// A capped open-files list plus the pre-cap total, so the view can render a
/// `+N more` overflow indicator without re-counting.
public struct OpenFileList: Equatable {
    /// The entries to show — at most `cap` of them, in `lsof` order.
    public let files: [OpenFile]
    /// Total matching entries before the cap (`files.count` when nothing overflowed).
    public let total: Int

    public init(files: [OpenFile], total: Int) {
        self.files = files
        self.total = total
    }

    /// Number of entries hidden by the cap (0 when everything fits).
    public var overflow: Int { max(0, total - files.count) }
}

/// Resolves a single process's open files + sockets on-demand for the inspector
/// (PID-52.3) — fetched via `lsof -p <pid>` only when a row expands, never during
/// a scan. Unlike the per-scan provenance maps (`PortRegistry` / `CwdResolver` /
/// `AncestryResolver`), this is per-row and heavier, so the app-side caches it.
///
/// Mirrors `CwdResolver`'s split: a single per-PID-scoped `lsof` shell-out feeds a
/// pure, injectable parser; filtering + home-abbreviation + capping are pure. Stays
/// on the pinned `/usr/sbin/lsof` surface (no new binary, per PID-049). Empty when
/// the process holds nothing worth showing — the UI degrades gracefully (no line),
/// like the other hints.
public enum OpenFilesResolver {

    /// Default number of entries shown before the `+N more` overflow line.
    public static let defaultCap = 15

    /// Socket `lsof` types (network + unix-domain).
    private static let socketTypes: Set<String> = ["IPv4", "IPv6", "unix"]
    /// Regular-file `lsof` type.
    private static let fileType = "REG"

    /// Resolve open files for `pid`: parse, home-abbreviate file paths, count, and cap.
    /// `lsofOutput`, `home`, and `cap` are injectable for tests. Empty list when the
    /// process holds no matching files/sockets.
    public static func openFiles(forPID pid: Int32,
                                 lsofOutput: String? = nil,
                                 home: String = NSHomeDirectory(),
                                 cap: Int = defaultCap) -> OpenFileList {
        let output = lsofOutput ?? runLSOF(pid)
        let parsed = parseOpenFiles(lsofOutput: output).map { raw in
            raw.isSocket ? raw : OpenFile(name: CwdResolver.abbreviateHome(raw.name, home: home),
                                          isSocket: false)
        }
        return OpenFileList(files: Array(parsed.prefix(cap)), total: parsed.count)
    }

    /// Parse `lsof -p <pid> -Fftn` field output into the process's real open files +
    /// sockets. Records arrive as `f<fd>` / `t<type>` / `n<name>` triples. The filter
    /// is structural, not a path blocklist: keep only records whose fd is **numeric**
    /// — dropping `cwd` / `txt` / `rtd` / `mem`, where `txt` is exactly the
    /// memory-mapped executable + dylib/framework noise — then keep type `REG`
    /// (regular files) or a socket type (`IPv4` / `IPv6` / `unix`), dropping CHR ttys,
    /// pipes, kqueues, etc. Deduplicated by name, preserving first-seen order.
    /// Injectable for unit tests.
    public static func parseOpenFiles(lsofOutput: String) -> [OpenFile] {
        var result = [OpenFile]()
        var seen = Set<String>()
        var fd: String?
        var type: String?
        for line in lsofOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let s = String(line)
            guard let tag = s.first else { continue }
            let value = String(s.dropFirst())
            switch tag {
            case "f":
                fd = value; type = nil          // new record: reset the pending type
            case "t":
                type = value
            case "n":
                defer { fd = nil; type = nil }  // consume the record either way
                guard let fdVal = fd, Int(fdVal) != nil, let t = type, !value.isEmpty else { continue }
                let isSocket = socketTypes.contains(t)
                guard isSocket || t == fileType else { continue }
                if seen.insert(value).inserted {
                    result.append(OpenFile(name: value, isSocket: isSocket))
                }
            default:
                break
            }
        }
        return result
    }

    // MARK: - lsof shell-out

    /// `-p <pid>` scopes to one process; `-Fftn` emits machine-parseable
    /// `f<fd>` / `t<type>` / `n<name>` field lines. On-demand (per expanded row),
    /// never per-scan.
    static func runLSOF(_ pid: Int32) -> String {
        Shell.run("/usr/sbin/lsof", ["-p", String(pid), "-Fftn"], timeout: Shell.Budget.lsof).output
    }
}
