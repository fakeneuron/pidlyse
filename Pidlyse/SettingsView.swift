import PidlyseCore
import ServiceManagement
import SwiftUI

/// Settings panel: scan interval, stale-process threshold, ignored command prefixes.
/// Opened via Cmd+, or the gear button in the popover header.
struct SettingsView: View {
    @ObservedObject var engine: ScanEngine

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enable in
                do {
                    if enable {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Registration can fail if the user denies the system prompt.
                }
            }
        )
    }

    /// Binding for one kind's "scanned" toggle — on when the kind is *not* in the
    /// engine's `disabledKinds` set. Flipping off inserts it (skipped next scan).
    private func kindEnabled(_ kind: ProcessKind) -> Binding<Bool> {
        Binding(
            get: { !engine.disabledKinds.contains(kind) },
            set: { enabled in
                if enabled {
                    engine.disabledKinds.remove(kind)
                } else {
                    engine.disabledKinds.insert(kind)
                }
            }
        )
    }

    /// Binding that joins/splits `ignoredNames` on newlines for the TextEditor.
    private var ignoredNamesText: Binding<String> {
        Binding(
            get: { engine.ignoredNames.joined(separator: "\n") },
            set: {
                engine.ignoredNames = $0
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    /// Binding that joins/splits `customRules` on newlines for the TextEditor —
    /// one `substring = label` rule per line, mirroring `ignoredNamesText`.
    private var customRulesText: Binding<String> {
        Binding(
            get: { engine.customRules.map(CustomRule.serialize).joined(separator: "\n") },
            set: {
                engine.customRules = $0
                    .components(separatedBy: "\n")
                    .compactMap(CustomRule.parse)
            }
        )
    }

    /// Binding that joins/splits `protectedProjects` on newlines for the TextEditor —
    /// one `~`-abbreviated project path per line, mirroring `ignoredNamesText` (PID-54.4).
    private var protectedProjectsText: Binding<String> {
        Binding(
            get: { engine.protectedProjects.joined(separator: "\n") },
            set: {
                engine.protectedProjects = $0
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLogin)
            }
            Section("Notifications") {
                Toggle("Alert on new strays", isOn: $engine.notificationsEnabled)
                Text("Shows a system notification when a background scan detects processes not seen in the previous scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Auto-scan") {
                Stepper(
                    "Every \(Int(engine.scanInterval / 60)) min",
                    value: $engine.scanInterval,
                    in: 60.0...3600.0,
                    step: 60.0
                )
                Stepper(
                    "Stale after \(Int(engine.elapsedThreshold / 60)) min",
                    value: $engine.elapsedThreshold,
                    in: 300.0...7200.0,
                    step: 300.0
                )
            }
            Section("Ignored processes") {
                TextEditor(text: ignoredNamesText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                Text("One command substring per line — matching processes are hidden. Append ` @ <path>` to scope a rule to one project tree (e.g. `node @ ~/code/bidviz`).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Custom rules") {
                TextEditor(text: customRulesText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                Text("One rule per line as `substring = label` — matching processes surface under the label in Needs Review (never auto-killable).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Protected projects") {
                TextEditor(text: protectedProjectsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                Text("One project path per line — processes whose working directory is under that tree are kept out of \u{201C}Clean all\u{201D} (still listed and individually killable). Add or remove with the 🔒 button on a Safe row.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Scanned kinds") {
                // `.custom` is excluded — it's the sentinel for user rules above,
                // not a togglable built-in category.
                ForEach(ProcessKind.allCases.filter { $0 != .custom }, id: \.rawValue) { kind in
                    Toggle(kind.label, isOn: kindEnabled(kind))
                }
                Text("Unchecked kinds are skipped during scans — like Ignored processes, but by category.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .navigationTitle("Pidlyse")
    }
}
