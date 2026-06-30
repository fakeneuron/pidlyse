import SwiftUI
import PidlyseCore

/// The popover content: a live two-section list (Safe / Needs Review) bound to
/// `ScanEngine`, with rows grouped by `kind`. Safe items can be swept with one
/// "Clean all safe" click; every row also carries an individual kill button.
/// Kills route through `KillService` (SIGTERM → 2 s → SIGKILL) and trigger a
/// rescan. Never auto-kills — every kill is an explicit click (per CLAUDE.md).
struct MenuBarView: View {
    /// The two popover tabs, switched via the segmented control below the header.
    private enum Tab { case processes, containers }

    @ObservedObject var engine: ScanEngine
    /// Opens the Settings window. Injected by `AppDelegate`, which presents a
    /// self-managed AppKit window (see `AppDelegate.openSettings()`) — the SwiftUI
    /// `Settings` scene can't be opened from this out-of-scene-graph popover.
    let openSettings: () -> Void
    @State private var selectedTab: Tab = .processes
    /// Bumped by the shared header refresh while the Containers tab is active so
    /// the one `↻` reloads the locally-stateful `ContainersView`.
    @State private var containerRefreshToken = 0
    @State private var expandedPIDs: Set<Int32> = []
    /// Kinds that are collapsed. Populated lazily when each kind first appears:
    /// high-risk groups start collapsed; easy/moderate start expanded.
    @State private var collapsedKinds: Set<ProcessKind> = []
    @State private var seenKinds: Set<ProcessKind> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tabPicker
            switch selectedTab {
            case .processes:
                if engine.items.isEmpty {
                    emptyState
                } else {
                    content
                }
            case .containers:
                ContainersView(refreshToken: containerRefreshToken)
            }
        }
        .frame(width: 320)
        .onAppear { engine.scan() }
        .onChange(of: engine.isScanning) { _, isScanning in
            guard !isScanning else { return }
            initCollapsedKinds()
        }
    }

    // MARK: - Init helpers

    private func initCollapsedKinds() {
        for (kind, rows) in grouped(engine.items) {
            guard !seenKinds.contains(kind) else { continue }
            seenKinds.insert(kind)
            if rows.contains(where: { $0.riskTier == .high }) {
                collapsedKinds.insert(kind)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Pidlyse").font(.headline)
            Spacer()
            Button {
                switch selectedTab {
                case .processes:  engine.rescan()
                case .containers: containerRefreshToken += 1
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(selectedTab == .processes ? "Rescan (restores hidden items)" : "Refresh containers")
            Button {
                openSettings()
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Pidlyse")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("Processes").tag(Tab.processes)
            Text("Containers").tag(Tab.containers)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        Text("No stray processes detected.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !safeItems.isEmpty { safeSection }
                if !reviewItems.isEmpty { reviewSection }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // Fixed height so the window opens to a usable size instead of
        // collapsing to the ScrollView's minimum (which hid the rows).
        .frame(height: 360)
    }

    private var safeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Safe to clean (\(safeItems.count))")
                    .font(.subheadline).bold()
                Spacer()
                Button("Clean all") {
                    KillService.kill(safeItems, containerOwners: engine.containerOwners) { engine.scan() }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            groups(for: safeItems)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Needs review (\(reviewItems.count))")
                .font(.subheadline).bold()
            groups(for: reviewItems)
        }
    }

    /// Render `items` grouped under a collapsible per-kind header. High-risk
    /// groups start collapsed; easy/moderate start expanded.
    private func groups(for items: [ProcessItem]) -> some View {
        ForEach(grouped(items), id: \.0) { kind, rows in
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if collapsedKinds.contains(kind) {
                            collapsedKinds.remove(kind)
                        } else {
                            collapsedKinds.insert(kind)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: collapsedKinds.contains(kind) ? "chevron.right" : "chevron.down")
                            .font(.caption2)
                        Text(kind.label)
                            .font(.caption).foregroundStyle(.secondary)
                        if collapsedKinds.contains(kind) {
                            let totalCPU = rows.reduce(0.0) { $0 + $1.cpuPercent }
                            let totalRAM = rows.reduce(0) { $0 + $1.rssKB }
                            Text("·")
                                .font(.caption2).foregroundStyle(.tertiary)
                            Text(String(format: "%.1f%%", totalCPU))
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(ramString(totalRAM))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                if !collapsedKinds.contains(kind) {
                    ForEach(rows) { row($0) }
                }
            }
        }
    }

    private func riskColor(_ tier: RiskTier) -> Color {
        switch tier {
        case .easy:     return .green
        case .moderate: return .orange
        case .high:     return .red
        }
    }

    /// Always-visible secondary line under the PID: the git-project the process runs in
    /// (`bidviz` / `bidviz/frontend`) when resolvable — the owner hint PID-038 targets.
    /// Falls back to the compact executable path when cwd can't be resolved. The group
    /// header already carries the kind, so a bare `npm`/`node` `displayPath` is
    /// redundant; the project answers "which app / dev server is this?".
    private func rowDescriptor(_ item: ProcessItem) -> String {
        engine.cwds[item.pid]?.label ?? item.displayPath
    }

    private func row(_ item: ProcessItem) -> some View {
        let isOld = item.elapsed >= engine.elapsedThreshold
        let isExpanded = expandedPIDs.contains(item.pid)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(riskColor(item.riskTier))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PID \(item.pid)").font(.caption).monospaced()
                    Text(rowDescriptor(item))
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                        .help(engine.cwds[item.pid]?.fullPath ?? item.command)
                }
                Spacer()
                Text(String(format: "%.1f%%", item.cpuPercent))
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                Text(ramString(item.rssKB))
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
                Text(ageString(item.elapsed))
                    .font(.caption2).foregroundStyle(.secondary)
                Button {
                    if expandedPIDs.contains(item.pid) {
                        expandedPIDs.remove(item.pid)
                    } else {
                        expandedPIDs.insert(item.pid)
                    }
                } label: {
                    Image(systemName: isExpanded ? "info.circle.fill" : "info.circle")
                }
                .buttonStyle(.borderless)
                .help("Why is this here?")
                Button {
                    engine.dismiss(item.pid)
                } label: {
                    Image(systemName: "eye.slash")
                }
                .buttonStyle(.borderless)
                .help("Ignore for session")
                Button {
                    KillService.kill(item, containerOwners: engine.containerOwners) { engine.scan() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Kill PID \(item.pid)")
            }
            if isExpanded {
                reasoningBlock(item: item, isOld: isOld)
            }
        }
    }

    private func reasoningBlock(item: ProcessItem, isOld: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if !item.hasTTY { criterionTag("no tty") }
                if item.isOrphan { criterionTag("orphan") }
                if isOld { criterionTag("old") }
            }
            Text("tty \(item.tty)  ·  ppid \(item.ppid)  ·  age \(ageString(item.elapsed))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
            // Provenance hints (PID-036.3): rendered only when resolvable, so a
            // process with no registered-port listener / no scanned parent simply
            // shows fewer lines (graceful degrade). The cwd / project-folder hint
            // (PID-038) is promoted to the always-visible row descriptor instead of a
            // line here — see `rowDescriptor`.
            if let ports = engine.listeningPorts[item.pid], !ports.isEmpty {
                Text("\(ports.sorted().map { ":\($0)" }.joined(separator: ", ")) listening")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let parent = ScanCore.parentCommand(ofPPID: item.ppid, in: engine.items) {
                Text("child of \(parent)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            if let owner = engine.containerOwners[item.pid] {
                Text("owned by container \(owner)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(.leading, 4)
        .padding(.bottom, 4)
    }

    private func criterionTag(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.12))
            .foregroundStyle(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Derived data

    private var safeItems: [ProcessItem] { engine.items.filter { $0.bucket == .safe } }
    private var reviewItems: [ProcessItem] { engine.items.filter { $0.bucket == .needsReview } }

    private func grouped(_ items: [ProcessItem]) -> [(ProcessKind, [ProcessItem])] {
        ProcessKind.allCases.compactMap { kind in
            let matches = items.filter { $0.kind == kind }
            return matches.isEmpty ? nil : (kind, matches)
        }
    }

    private func ramString(_ kb: Int) -> String {
        let mb = kb / 1024
        return mb > 0 ? "\(mb) MB" : "\(kb) KB"
    }

    /// Compact human-readable elapsed age (`45s` / `12m` / `3h` / `2d`).
    private func ageString(_ t: TimeInterval) -> String {
        let s = Int(t)
        switch s {
        case ..<60:    return "\(s)s"
        case ..<3600:  return "\(s / 60)m"
        case ..<86400: return "\(s / 3600)h"
        default:       return "\(s / 86400)d"
        }
    }
}
