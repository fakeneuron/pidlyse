import XCTest
@testable import PidlyseCore

final class PortRegistryTests: XCTestCase {

    // MARK: - PortRegistry.parsePIDAndPort

    func testParsePIDAndPort_registeredPort_returnsPID() {
        // 3001 is siteguy's frontend port — in registeredPorts.
        let line = "node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)"
        let pid = PortRegistry.parsePIDAndPort(line)
        XCTAssertEqual(pid, 1234)
    }

    func testParsePIDAndPort_unregisteredPort_returnsNil() {
        let line = "ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)"
        XCTAssertNil(PortRegistry.parsePIDAndPort(line))
    }

    func testParsePIDAndPort_headerLine_returnsNil() {
        let line = "COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
        XCTAssertNil(PortRegistry.parsePIDAndPort(line))
    }

    // MARK: - PortRegistry.listeningPIDs

    func testListeningPIDs_multiLine_returnsAllRegisteredPIDs() {
        // Two different PIDs on two different registered ports.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        python     5678 user  11u  IPv4 0x0  0t0  TCP *:5173 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234, 5678])
    }

    func testListeningPIDs_duplicatePID_deduplicates() {
        // Same PID listening on two registered ports → appears only once in the result.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        node       1234 user  23u  IPv4 0x0  0t0  TCP *:3002 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234])
    }

    func testListeningPIDs_headerLine_skipped() {
        // Header line ("COMMAND PID …") must not contribute a PID.
        let output = """
        COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234])
    }

    // MARK: - PortRegistry.parseListenerLine

    func testParseListenerLine_registeredPort_returnsPIDAndPort() {
        let line = "node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)"
        let match = PortRegistry.parseListenerLine(line)
        XCTAssertEqual(match?.pid, 1234)
        XCTAssertEqual(match?.port, 3001)
    }

    func testParseListenerLine_unregisteredPort_returnsNil() {
        let line = "ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)"
        XCTAssertNil(PortRegistry.parseListenerLine(line))
    }

    // MARK: - PortRegistry.listeningPorts (PID-036.2 — PID→port map)

    func testListeningPorts_multiLine_mapsEachPIDToItsPort() {
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        python     5678 user  11u  IPv4 0x0  0t0  TCP *:5173 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001], 5678: [5173]])
    }

    func testListeningPorts_samePIDmultiplePorts_accumulates() {
        // One PID listening on two registered ports → both collected under that PID.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        node       1234 user  23u  IPv4 0x0  0t0  TCP *:3002 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001, 3002]])
    }

    func testListeningPorts_headerAndUnregistered_skipped() {
        let output = """
        COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001]])
    }

    func testListeningPorts_empty_returnsEmpty() {
        XCTAssertTrue(PortRegistry.listeningPorts(lsofOutput: "").isEmpty)
    }

    // MARK: - PortRegistry.scanListeningPorts (PID-090 — no data vs no listeners)

    func testScanListeningPorts_unfinishedRunIsUnavailable() {
        // Expiry or launch failure (`Shell.runReporting` finished == false).
        XCTAssertNil(PortRegistry.scanListeningPorts(lsof: ("", false, false)))
    }

    func testScanListeningPorts_finishedEmptyRunIsAnEmptyMap() {
        // lsof exits 1 with no output when nothing listens: no listeners, not no data.
        XCTAssertEqual(PortRegistry.scanListeningPorts(lsof: ("", false, true)), [:])
    }

    func testScanListeningPorts_finishedRunParsesListeners() {
        let output = "node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)"
        XCTAssertEqual(PortRegistry.scanListeningPorts(lsof: (output, true, true)), [1234: [3001]])
    }

    // MARK: - PortRegistry.registeredPorts (anti-drift canary)

    /// Tripwire for the manually-synced port table. `registeredPorts` mirrors
    /// `~/Code/natabula/docs/PORT-REGISTRY.md` by hand; if an edit
    /// accidentally drops or corrupts a known port, this assertion fails under
    /// `make test`. Each port is an anchor for an active project — keep this
    /// canary in sync when the registry changes.
    func testRegisteredPorts_canaryKnownPorts() {
        let known: [Int] = [
            5182,   // InvisiPaw frontend
            8001,   // InvisiPaw backend
            3001,   // siteguy frontend
            4000,   // marscharts frontend
            5120,   // flaitron/viz
            5899,   // stockshock frontend
            8005,   // bidviz backend
            3002,   // fakeneuron
            4321,   // sciphoenix
            5184,   // wandora frontend
            5183,   // delparte
            3003,   // blastimage
            5185,   // finanal frontend
            // PID-075 re-sync additions
            5189, 8099,   // InvisiPaw e2e
            5197,         // siteguy landing
            5503,         // ADPpro e2e
            5193,         // natabula
            4173,         // bidviz e2e
            3009,         // blastimage e2e
            5186, 8787,   // email-manager
            5187, 8009,   // 3pnf Studio
            5190, 8010, 5196, 8015,   // invisibrain (+ e2e)
            5191, 8012, 5194, 8014,   // cloutomaton (+ e2e)
            5192,         // neromercato
            5195, 8013,   // caobunga
            4007,         // postiz
            5198,         // judedelparte
        ]
        for port in known {
            XCTAssertTrue(PortRegistry.registeredPorts.contains(port),
                          "registeredPorts is missing known port \(port) — manual sync table drifted from natabula docs/PORT-REGISTRY.md")
        }
    }

    // MARK: - PortRegistry.mergedPorts (PID-025 user override merge)

    func testMergedPorts_unionAddsUserPorts() {
        // Keyed-by-project JSON adds two ports not in the built-in set.
        let json = #"{"newproj": [9100, 9200]}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: json)
        XCTAssertEqual(merged, [3001, 8003, 9100, 9200])
    }

    func testMergedPorts_flattensMultipleProjects() {
        // Port lists across multiple project keys are flattened into one set.
        let json = #"{"siteguy": [3001, 8003], "bidviz": [5181, 8005]}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [1111], userJSON: json)
        XCTAssertEqual(merged, [1111, 3001, 8003, 5181, 8005])
    }

    func testMergedPorts_nilJSON_returnsBuiltInUnchanged() {
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: nil)
        XCTAssertEqual(merged, [3001, 8003])
    }

    func testMergedPorts_malformedJSON_fallsBackToBuiltIn() {
        // Garbage / wrong-shape JSON must not throw or empty the registry.
        let json = #"{ not valid json "#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: json)
        XCTAssertEqual(merged, [3001, 8003])
    }

    func testMergedPorts_wrongShapeJSON_fallsBackToBuiltIn() {
        // Valid JSON but not [String: [Int]] (a flat array) → built-ins unchanged.
        let json = #"[3001, 8003]"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [5500], userJSON: json)
        XCTAssertEqual(merged, [5500])
    }

    func testMergedPorts_emptyObject_returnsBuiltInUnchanged() {
        let json = #"{}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001], userJSON: json)
        XCTAssertEqual(merged, [3001])
    }
}
