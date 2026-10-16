import XCTest
@testable import PidlyseCore

final class ProcessItemTests: XCTestCase {

    // MARK: - displayPath

    private func item(command: String) -> ProcessItem {
        ProcessItem(pid: 1, ppid: 1, command: command, elapsed: 0,
                    tty: "??", kind: .pytest, riskTier: .easy, cpuPercent: 0, rssKB: 0)
    }

    func testDisplayPath_absolutePathWithArgs_showsParentSlashExec() {
        XCTAssertEqual(item(command: "/usr/local/bin/uvicorn main:app --reload").displayPath,
                       "bin/uvicorn")
    }

    func testDisplayPath_bareWordCommand_showsFirstToken() {
        XCTAssertEqual(item(command: "npm run dev").displayPath, "npm")
    }

    func testDisplayPath_absoluteNoArgs_showsParentSlashExec() {
        XCTAssertEqual(item(command: "/Applications/Docker.app/Contents/MacOS/com.docker.backend").displayPath,
                       "MacOS/com.docker.backend")
    }

    func testDisplayPath_singleAbsolutePath_showsExecName() {
        XCTAssertEqual(item(command: "/uvicorn").displayPath, "uvicorn")
    }
}
