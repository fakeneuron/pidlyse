import XCTest
@testable import PidlyseCore

/// Tests for the pure docker-binary trust policy added in PID-35.3 (F2). The impure
/// `isTrustedExecutable` filesystem read is not unit-tested (mirrors `ScanCore.runPS`).
final class DockerServiceTests: XCTestCase {

    private let user: UInt32 = 501

    func testTrust_rootOwned_notWorldWritable_trusted() {
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o755, currentUID: user))
    }

    func testTrust_currentUserOwned_notWorldWritable_trusted() {
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: user, permissions: 0o755, currentUID: user))
    }

    func testTrust_groupWritable_stillTrusted() {
        // Lenient policy: group-writable is allowed (e.g. /usr/local/bin admin group
        // on Intel) — only world-writable and foreign ownership are rejected.
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o775, currentUID: user))
    }

    func testTrust_worldWritable_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o757, currentUID: user))
    }

    func testTrust_rootOwnedButWorldWritable_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o777, currentUID: user))
    }

    func testTrust_foreignOwner_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 999, permissions: 0o755, currentUID: user))
    }
}
