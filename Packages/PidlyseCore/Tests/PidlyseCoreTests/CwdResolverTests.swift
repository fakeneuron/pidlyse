import XCTest
@testable import PidlyseCore

final class CwdResolverTests: XCTestCase {

    // MARK: - parseCwds (lsof -Fpn field output)

    func testParseCwds_multiplePIDs_mapsEachToItsCwd() {
        // Two process sets: each `p<pid>` line is followed by its cwd `n<path>` line.
        let lsof = "p200\nn/Users/x/code/bidviz\np300\nn/Users/x/code/foo\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof),
                       [200: "/Users/x/code/bidviz", 300: "/Users/x/code/foo"])
    }

    func testParseCwds_processWithoutNameLine_skipped() {
        // A process set with no following `n` line contributes nothing.
        let lsof = "p200\np300\nn/Users/x/code/foo\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof), [300: "/Users/x/code/foo"])
    }

    func testParseCwds_unparseablePID_dropsAttachedName() {
        // A malformed `p` value leaves currentPID nil → the following name is ignored.
        let lsof = "pXYZ\nn/Users/x/code/foo\np400\nn/Users/x/code/bar\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof), [400: "/Users/x/code/bar"])
    }

    func testParseCwds_empty_returnsEmpty() {
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: ""), [:])
    }

    // MARK: - abbreviateHome

    func testAbbreviateHome_pathUnderHome_collapsesToTilde() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x/code/bidviz", home: "/Users/x"),
                       "~/code/bidviz")
    }

    func testAbbreviateHome_exactHome_returnsTilde() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x", home: "/Users/x"), "~")
    }

    func testAbbreviateHome_outsideHome_unchanged() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/opt/homebrew/bin", home: "/Users/x"),
                       "/opt/homebrew/bin")
    }

    func testAbbreviateHome_homePrefixButNotBoundary_unchanged() {
        // "/Users/xavier" must not match home "/Users/x" — boundary is the slash.
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/xavier/code", home: "/Users/x"),
                       "/Users/xavier/code")
    }

    func testAbbreviateHome_emptyHome_unchanged() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x/code", home: ""), "/Users/x/code")
    }

    // MARK: - projectLabel (git-root → short label)

    func testProjectLabel_cwdIsRepoRoot_returnsRepoName() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/Users/x/code/bidviz",
                                                gitRoot: "/Users/x/code/bidviz"), "bidviz")
    }

    func testProjectLabel_cwdInSubfolder_returnsRepoSlashSubpath() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/Users/x/code/bidviz/frontend",
                                                gitRoot: "/Users/x/code/bidviz"), "bidviz/frontend")
    }

    func testProjectLabel_notInRepo_returnsLeafFolderName() {
        // No git root found → the leaf folder, never the full path (short + readable).
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/opt/homebrew/var", gitRoot: nil), "var")
    }

    func testProjectLabel_nilRoot_emptyCwd_returnsCwd() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/", gitRoot: nil), "/")
    }

    // MARK: - processCwds (injected lsof + home + gitRootFinder)

    func testProcessCwds_emptyPIDs_returnsEmptyWithoutShellOut() {
        XCTAssertEqual(CwdResolver.processCwds(forPIDs: [], home: "/Users/x"), [:])
    }

    func testProcessCwds_buildsLabelAndAbbreviatedFullPath() {
        let lsof = "p200\nn/Users/x/code/bidviz/frontend\n"
        let result = CwdResolver.processCwds(forPIDs: [200], lsofOutput: lsof, home: "/Users/x",
                                             gitRootFinder: { _ in "/Users/x/code/bidviz" })
        XCTAssertEqual(result, [200: ProcessCwd(label: "bidviz/frontend",
                                                fullPath: "~/code/bidviz/frontend",
                                                projectRoot: "~/code/bidviz")])
    }

    func testProcessCwds_noGitRoot_labelIsLeafFolder() {
        let lsof = "p200\nn/Users/x/scratch\n"
        let result = CwdResolver.processCwds(forPIDs: [200], lsofOutput: lsof, home: "/Users/x",
                                             gitRootFinder: { _ in nil })
        // No repo → projectRoot is nil (protect falls back to the exact cwd).
        XCTAssertEqual(result, [200: ProcessCwd(label: "scratch", fullPath: "~/scratch",
                                                projectRoot: nil)])
    }

    // MARK: - isUnderPrefix (protect + scoped-ignore path containment, PID-54.4)

    func testIsUnderPrefix_exactMatchAndDescendant() {
        XCTAssertTrue(CwdResolver.isUnderPrefix("~/code/bidviz", "~/code/bidviz"))
        XCTAssertTrue(CwdResolver.isUnderPrefix("~/code/bidviz/frontend", "~/code/bidviz"))
    }

    func testIsUnderPrefix_siblingAndPartialSegment_notMatched() {
        XCTAssertFalse(CwdResolver.isUnderPrefix("~/code/bidviz2", "~/code/bidviz"))
        XCTAssertFalse(CwdResolver.isUnderPrefix("~/code/marscharts", "~/code/bidviz"))
    }

    func testIsUnderPrefix_trailingSlashTolerated() {
        XCTAssertTrue(CwdResolver.isUnderPrefix("~/code/bidviz/frontend", "~/code/bidviz/"))
    }

    func testIsUnderPrefix_emptyPrefix_matchesNothing() {
        XCTAssertFalse(CwdResolver.isUnderPrefix("~/code/bidviz", ""))
    }
}
