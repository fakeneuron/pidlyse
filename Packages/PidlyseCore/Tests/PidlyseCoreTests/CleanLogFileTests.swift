import Darwin
import XCTest
@testable import PidlyseCore

final class CleanLogFileTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pidlyse-tests-\(UUID().uuidString)/clean-log.json")
    }

    override func tearDown() {
        CleanLogFile.overlapDelayForTests = 0
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func event(_ kind: String, at seconds: TimeInterval) -> CleanEvent {
        CleanEvent(kind: kind, projectLabel: "proj", rssKB: 100,
                   timestamp: Date(timeIntervalSince1970: 1_000_000 + seconds))
    }

    func testLoad_missingFile_returnsEmpty() {
        XCTAssertTrue(CleanLogFile.load(from: tempURL).isEmpty)
    }

    func testLoad_malformedJSON_returnsEmpty() throws {
        try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempURL)
        XCTAssertTrue(CleanLogFile.load(from: tempURL).isEmpty)
    }

    func testSaveLoad_roundTrip() {
        let events = [event("pytest", at: 0), event("npm", at: 10)]
        CleanLogFile.save(events, to: tempURL)
        XCTAssertEqual(CleanLogFile.load(from: tempURL), events)
    }

    func testAppend_mergesWithExisting_andPersists() {
        CleanLogFile.save([event("pytest", at: 0)], to: tempURL)
        let merged = CleanLogFile.append([event("npm", at: 10)], at: tempURL)
        XCTAssertEqual(merged.map { $0.kind }, ["pytest", "npm"])
        XCTAssertEqual(CleanLogFile.load(from: tempURL).map { $0.kind }, ["pytest", "npm"])
    }

    func testAppend_appliesCap_keepingNewest() {
        CleanLogFile.save([event("a", at: 0), event("b", at: 10)], to: tempURL)
        let merged = CleanLogFile.append([event("c", at: 20)], at: tempURL, cap: 2)
        XCTAssertEqual(merged.map { $0.kind }, ["b", "c"])
    }

    func testAppend_empty_isReadOnly() {
        // No directory is created and nothing is written for an empty append,
        // including the sibling lock file a real append would take.
        XCTAssertTrue(CleanLogFile.append([], at: tempURL).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.appendingPathExtension("lock").path))
    }

    /// Threads stand in for the app and the CLI. The sleep sits inside the
    /// locked section, so without the lock every writer would re-read the same
    /// snapshot and the last save would drop the rest. `flock` is what excludes
    /// the other process; `NSLock` is what makes this in-process overlap wait.
    func testAppend_overlappingWriters_keepsEveryEvent() {
        let count = 12
        CleanLogFile.overlapDelayForTests = 0.02
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "pidlyse.cleanlog.append", attributes: .concurrent)
        for i in 0..<count {
            group.enter()
            queue.async {
                CleanLogFile.append([self.event("e\(i)", at: TimeInterval(i))], at: self.tempURL)
                group.leave()
            }
        }
        let finished = group.wait(timeout: .now() + 10)
        XCTAssertEqual(finished, .success)
        let kinds = Set(CleanLogFile.load(from: tempURL).map(\.kind))
        XCTAssertEqual(kinds, Set((0..<count).map { "e\($0)" }))
    }

    /// A second process holds the sibling lock. `append` must wait for it.
    /// An in-process `NSLock` would not, so this is the check that decides the
    /// app-vs-CLI race. The holder is a tiny C program because `flock` has no
    /// macOS CLI.
    func testAppend_blocksWhileAnotherProcessHoldsTheLock() throws {
        let dir = tempURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sourceURL = dir.appendingPathComponent("holdlock.c")
        let binaryURL = dir.appendingPathComponent("holdlock")
        let source = """
        #include <fcntl.h>
        #include <unistd.h>
        #include <sys/file.h>
        int main(int argc, char **argv) {
            int fd = open(argv[1], O_CREAT | O_RDWR, 0644);
            if (fd < 0 || flock(fd, LOCK_EX) != 0) return 1;
            if (write(1, "x", 1) != 1) return 2;
            usleep(400000);
            return 0;
        }
        """
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let compile = Process()
        compile.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        compile.arguments = ["-O0", "-o", binaryURL.path, sourceURL.path]
        try compile.run()
        compile.waitUntilExit()
        XCTAssertEqual(compile.terminationStatus, 0)

        let holder = Process()
        holder.executableURL = binaryURL
        holder.arguments = [tempURL.appendingPathExtension("lock").path]
        let pipe = Pipe()
        holder.standardOutput = pipe
        try holder.run()
        let ready = pipe.fileHandleForReading.readData(ofLength: 1)
        XCTAssertEqual(ready, Data("x".utf8))

        let start = Date()
        CleanLogFile.append([event("held", at: 0)], at: tempURL)
        let elapsed = Date().timeIntervalSince(start)
        holder.waitUntilExit()

        XCTAssertGreaterThanOrEqual(elapsed, 0.25)
        XCTAssertEqual(CleanLogFile.load(from: tempURL).map(\.kind), ["held"])
    }

    /// The lock fd is open across the blocking `flock` and the save. A spawn in
    /// that window inherits it unless the open used `O_CLOEXEC`. `Foundation.Process`
    /// (what `Shell.run` uses) closes stray fds itself, so this spawns with
    /// `posix_spawn` and no `POSIX_SPAWN_CLOEXEC_DEFAULT` — the path that leaks.
    func testAppend_spawnDuringAppend_doesNotInheritLockFd() throws {
        let dir = tempURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sourceURL = dir.appendingPathComponent("lockfd.c")
        let binaryURL = dir.appendingPathComponent("lockfd")
        let source = """
        #include <dirent.h>
        #include <fcntl.h>
        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>
        int main(int argc, char **argv) {
            if (argc < 2) return 2;
            char want[1024];
            if (realpath(argv[1], want) == NULL) return 2;
            DIR *d = opendir("/dev/fd");
            if (d == NULL) return 2;
            struct dirent *ent;
            int inherited = 0;
            while ((ent = readdir(d)) != NULL) {
                if (ent->d_name[0] < '0' || ent->d_name[0] > '9') continue;
                char got[1024];
                if (fcntl(atoi(ent->d_name), F_GETPATH, got) != 0) continue;
                if (strcmp(got, want) == 0) inherited = 1;
            }
            closedir(d);
            return inherited ? 1 : 0;
        }
        """
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let compile = Process()
        compile.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        compile.arguments = ["-O0", "-o", binaryURL.path, sourceURL.path]
        try compile.run()
        compile.waitUntilExit()
        XCTAssertEqual(compile.terminationStatus, 0)

        CleanLogFile.overlapDelayForTests = 0.8
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            CleanLogFile.append([self.event("spawn", at: 0)], at: self.tempURL)
            group.leave()
        }

        let lockPath = tempURL.appendingPathExtension("lock").path
        let deadline = Date().addingTimeInterval(2)
        var held = false
        while Date() < deadline {
            let fd = open(lockPath, O_RDWR)
            if fd >= 0 {
                let rc = flock(fd, LOCK_EX | LOCK_NB)
                if rc != 0 {
                    held = true
                    close(fd)
                    break
                }
                flock(fd, LOCK_UN)
                close(fd)
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(held, "append did not take the lock before the spawn window closed")

        var pid: pid_t = 0
        let arguments = [binaryURL.path, lockPath]
        let spawned: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
        defer { spawned.forEach { free($0) } }
        let rc = spawned.withUnsafeBufferPointer { buf in
            binaryURL.path.withCString { cPath in
                posix_spawn(&pid, cPath, nil, nil, buf.baseAddress, environ)
            }
        }
        XCTAssertEqual(rc, 0)
        guard rc == 0 else {
            _ = group.wait(timeout: .now() + 5)
            return
        }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue((status & 0x7f) == 0, "checker did not exit, status \(status)")
        XCTAssertEqual((status >> 8) & 0xff, 0, "child inherited the lock fd")
    }

    /// The format contract both writers share: ISO-8601 dates, so a log written
    /// by the CLI decodes in the app's store (and vice versa).
    func testSave_writesISO8601Dates() throws {
        CleanLogFile.save([event("vite", at: 0)], to: tempURL)
        let json = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(json.contains("\"1970-01-12T13:46:40Z\""))
    }
}
