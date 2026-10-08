import XCTest
@testable import PidlyseCore

final class OpenFilesResolverTests: XCTestCase {

    // MARK: - parseOpenFiles (lsof -p <pid> -Fftn field output)

    /// A realistic `-Fftn` fixture: cwd/txt/mem records (the dylib/framework noise)
    /// carry non-numeric fds; real open files + sockets carry numeric fds.
    private let fixture = """
    p668
    fcwd
    tDIR
    n/
    ftxt
    tREG
    n/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
    fmem
    tREG
    n/usr/lib/libSystem.B.dylib
    f3
    tREG
    n/Users/x/code/app/data.db
    f4
    tIPv4
    n127.0.0.1:5432->127.0.0.1:53000
    f5
    tunix
    n/private/tmp/app.sock
    f6
    tCHR
    n/dev/ttys000

    """

    func testParseOpenFiles_keepsNumericFdRegularFiles_dropsTxtAndMemNoise() {
        let files = OpenFilesResolver.parseOpenFiles(lsofOutput: fixture)
        // The two REG dylib/app records (fd `txt` / `mem`) are dropped structurally;
        // only the numeric-fd REG file survives among regular files.
        XCTAssertTrue(files.contains(OpenFile(name: "/Users/x/code/app/data.db", isSocket: false)))
        XCTAssertFalse(files.contains { $0.name.hasSuffix("Finder") })
        XCTAssertFalse(files.contains { $0.name.hasSuffix(".dylib") })
    }

    func testParseOpenFiles_keepsSockets_setsIsSocket() {
        let files = OpenFilesResolver.parseOpenFiles(lsofOutput: fixture)
        XCTAssertTrue(files.contains(OpenFile(name: "127.0.0.1:5432->127.0.0.1:53000", isSocket: true)))
        XCTAssertTrue(files.contains(OpenFile(name: "/private/tmp/app.sock", isSocket: true)))
    }

    func testParseOpenFiles_dropsNonFileNonSocketTypes() {
        // fd 6 is numeric but type CHR (a tty device) → not a regular file or socket.
        let files = OpenFilesResolver.parseOpenFiles(lsofOutput: fixture)
        XCTAssertFalse(files.contains { $0.name == "/dev/ttys000" })
    }

    func testParseOpenFiles_orderAndCountMatchNumericFileRecords() {
        // data.db (REG), the IPv4 socket, then the unix socket — lsof order preserved.
        let files = OpenFilesResolver.parseOpenFiles(lsofOutput: fixture)
        XCTAssertEqual(files.map { $0.name },
                       ["/Users/x/code/app/data.db",
                        "127.0.0.1:5432->127.0.0.1:53000",
                        "/private/tmp/app.sock"])
    }

    func testParseOpenFiles_deduplicatesByName_preservingFirstSeenOrder() {
        let lsof = "f3\ntREG\nn/tmp/a\nf4\ntREG\nn/tmp/a\nf5\ntREG\nn/tmp/b\n"
        XCTAssertEqual(OpenFilesResolver.parseOpenFiles(lsofOutput: lsof).map { $0.name },
                       ["/tmp/a", "/tmp/b"])
    }

    func testParseOpenFiles_empty_returnsEmpty() {
        XCTAssertEqual(OpenFilesResolver.parseOpenFiles(lsofOutput: ""), [])
    }

    func testParseOpenFiles_recordMissingType_skipped() {
        // An `f`/`n` pair with no `t` line in between can't be classified → dropped.
        let lsof = "f3\nn/tmp/a\nf4\ntREG\nn/tmp/b\n"
        XCTAssertEqual(OpenFilesResolver.parseOpenFiles(lsofOutput: lsof).map { $0.name }, ["/tmp/b"])
    }

    // MARK: - openFiles (home-abbreviation + cap)

    func testOpenFiles_abbreviatesFilePaths_notSocketNames() {
        let result = OpenFilesResolver.openFiles(forPID: 668, lsofOutput: fixture, home: "/Users/x")
        XCTAssertEqual(result.files, [
            OpenFile(name: "~/code/app/data.db", isSocket: false),
            OpenFile(name: "127.0.0.1:5432->127.0.0.1:53000", isSocket: true),
            OpenFile(name: "/private/tmp/app.sock", isSocket: true),
        ])
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.overflow, 0)
    }

    func testOpenFiles_capsListAndReportsOverflow() {
        let lsof = "f3\ntREG\nn/tmp/a\nf4\ntREG\nn/tmp/b\nf5\ntREG\nn/tmp/c\n"
        let result = OpenFilesResolver.openFiles(forPID: 1, lsofOutput: lsof, home: "/nohome", cap: 2)
        XCTAssertEqual(result.files.map { $0.name }, ["/tmp/a", "/tmp/b"])
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.overflow, 1)
    }

    func testOpenFiles_empty_returnsEmptyListNoOverflow() {
        let result = OpenFilesResolver.openFiles(forPID: 1, lsofOutput: "", home: "/Users/x")
        XCTAssertTrue(result.files.isEmpty)
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.overflow, 0)
    }
}
