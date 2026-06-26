import ServiceManagement

/// Manages the PidlyHelper LaunchAgent via `SMAppService.agent(plistName:)`.
/// The plist lives at `Contents/Library/LaunchAgents/com.fakeneuron.pidly.helper.plist`
/// in the app bundle; the helper executable is embedded at `Contents/Helpers/PidlyHelper`.
/// The settings toggle that gates registration lives in PID-27.6 (`SettingsView`).
enum LaunchAgentService {
    private static let plistName = "com.fakeneuron.pidly.helper.plist"

    static var status: SMAppService.Status {
        SMAppService.agent(plistName: plistName).status
    }

    static func register() throws {
        try SMAppService.agent(plistName: plistName).register()
    }

    static func unregister() async throws {
        try await SMAppService.agent(plistName: plistName).unregister()
    }
}
