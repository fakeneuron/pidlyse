import XCTest
@testable import PidlyseCore

/// Tests for the pure `docker ps` parser added in PID-28.2. The impure
/// `DockerService` shell-out is not unit-tested (mirrors `ScanCore.runPS`).
final class DockerCoreTests: XCTestCase {

    // MARK: - parseLine

    func testParseLine_fullRow() {
        let line = "abc123\tpg-db\tpostgres:16\tUp 3 minutes\t0.0.0.0:5432->5432/tcp\tsupabase"
        let c = DockerCore.parseLine(line)
        XCTAssertEqual(c?.id, "abc123")
        XCTAssertEqual(c?.name, "pg-db")
        XCTAssertEqual(c?.image, "postgres:16")
        XCTAssertEqual(c?.status, "Up 3 minutes")
        XCTAssertEqual(c?.ports, "0.0.0.0:5432->5432/tcp")
        XCTAssertEqual(c?.composeProject, "supabase")
    }

    func testParseLine_emptyComposeLabel_isNil() {
        // Non-compose container → the label field renders empty → nil project.
        let line = "abc123\tpg-db\tpostgres:16\tUp 3 minutes\t5432/tcp\t"
        XCTAssertNil(DockerCore.parseLine(line)?.composeProject)
    }

    func testParseLine_emptyPorts_kept() {
        // Container with no published ports → empty ports field, still valid.
        let line = "def456\tworker\talpine:latest\tUp 10 seconds\t\t"
        let c = DockerCore.parseLine(line)
        XCTAssertEqual(c?.id, "def456")
        XCTAssertEqual(c?.ports, "")
    }

    func testParseLine_tooFewFields_isNil() {
        XCTAssertNil(DockerCore.parseLine("abc123\tname\timage\tUp"))
        // Pre-compose-label 5-field form is malformed now — format + parser move in lockstep.
        XCTAssertNil(DockerCore.parseLine("abc123\tname\timage\tUp 3 minutes\t8080/tcp"))
    }

    func testParseLine_emptyID_isNil() {
        XCTAssertNil(DockerCore.parseLine("\tname\timage\tUp 1 minute\t8080/tcp\t"))
    }

    func testParseLine_blank_isNil() {
        XCTAssertNil(DockerCore.parseLine(""))
    }

    // MARK: - parsePS

    func testParsePS_multipleContainers() {
        let output = """
        abc123\tpg-db\tpostgres:16\tUp 3 minutes\t0.0.0.0:5432->5432/tcp\tsupabase
        def456\tredis\tredis:7\tUp 1 hour\t6379/tcp\t
        """
        let containers = DockerCore.parsePS(output)
        XCTAssertEqual(containers.count, 2)
        XCTAssertEqual(containers[0].name, "pg-db")
        XCTAssertEqual(containers[0].composeProject, "supabase")
        XCTAssertEqual(containers[1].image, "redis:7")
        XCTAssertNil(containers[1].composeProject)
    }

    func testParsePS_skipsBlankAndMalformedLines() {
        let output = """
        abc123\tpg-db\tpostgres:16\tUp 3 minutes\t5432/tcp\tsupabase

        garbage-no-tabs
        """
        let containers = DockerCore.parsePS(output)
        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers.first?.id, "abc123")
    }

    func testParsePS_empty_returnsEmpty() {
        XCTAssertTrue(DockerCore.parsePS("").isEmpty)
    }

    // MARK: - parseContainerOwners

    func testParseContainerOwners_mapsPIDToName_stripsLeadingSlash() {
        // `docker inspect {{.Name}}` carries a leading slash; it must be stripped.
        let output = "12345\t/pg-db\n67890\t/redis"
        let owners = DockerCore.parseContainerOwners(output)
        XCTAssertEqual(owners, [12345: "pg-db", 67890: "redis"])
    }

    func testParseContainerOwners_skipsPIDZero() {
        // State.Pid 0 = container not running → owns no host process.
        let owners = DockerCore.parseContainerOwners("0\t/stopped\n12345\t/live")
        XCTAssertEqual(owners, [12345: "live"])
    }

    func testParseContainerOwners_skipsMalformedAndBlankLines() {
        let output = "12345\t/ok\nno-tab-here\n\tabc\nnotanumber\t/x"
        let owners = DockerCore.parseContainerOwners(output)
        XCTAssertEqual(owners, [12345: "ok"])
    }

    func testParseContainerOwners_empty_returnsEmpty() {
        XCTAssertTrue(DockerCore.parseContainerOwners("").isEmpty)
    }

    // MARK: - parseStats

    func testParseStats_mapsIDToStats_stripsMemLimit() {
        // `{{.MemUsage}}` renders as `used / limit`; only the used half is kept.
        let output = "abc123\t0.15%\t45.2MiB / 7.667GiB\ndef456\t1.30%\t1.1GiB / 7.667GiB"
        let stats = DockerCore.parseStats(output)
        XCTAssertEqual(stats, ["abc123": ContainerStats(cpu: "0.15%", memory: "45.2MiB"),
                               "def456": ContainerStats(cpu: "1.30%", memory: "1.1GiB")])
    }

    func testParseStats_memUsageWithoutLimit_keptWhole() {
        // Defensive: a MemUsage with no ` / limit` tail passes through unsplit.
        let stats = DockerCore.parseStats("abc123\t0.50%\t45MiB")
        XCTAssertEqual(stats["abc123"], ContainerStats(cpu: "0.50%", memory: "45MiB"))
    }

    func testParseStats_skipsMalformedBlankAndEmptyIDLines() {
        let output = "abc123\t0.15%\t45MiB / 1GiB\nno-tabs-here\n\t1%\t2MiB / 4MiB\ntoo\tfew"
        let stats = DockerCore.parseStats(output)
        XCTAssertEqual(Array(stats.keys), ["abc123"])
    }

    func testParseStats_empty_returnsEmpty() {
        XCTAssertTrue(DockerCore.parseStats("").isEmpty)
    }
}
