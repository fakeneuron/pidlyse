import SwiftUI
import PidlyseCore

/// The popover content: a live two-section list (Safe / Needs Review) bound to
/// `ScanEngine`, with rows grouped by `kind`. Safe items can be swept with one
/// "Clean all safe" click; every row also carries an individual kill button.
/// Kills route through `KillService` (SIGTERM → 2 s → SIGKILL) and trigger a
/// rescan. Never auto-kills — every kill is an explicit click (per CLAUDE.md).
struct MenuBarView: View {
    /// The popover tabs, switched via the segmented control below the header.
    private enum Tab { case processes, containers, cleaned }

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
    /// Live filter for the Processes tab. Session-scoped: the hosting controller is
    /// reused across popover opens (see `AppDelegate`), so `@State` persists — the
    /// `.onDisappear` below clears it so each open starts unfiltered.
    @State private var filterText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tabPicker
            if selectedTab == .processes && !engine.items.isEmpty {
                searchField
            }
            switch selectedTab {
            case .processes:
                if engine.items.isEmpty {
                    emptyState
                } else {
                    content
                }
            case .containers:
                ContainersView(refreshToken: containerRefreshToken)
            case .cleaned:
                CleanedView(store: engine.cleanLog)
            }
        }
        .frame(width: 320)
        .background(soleSafeKillShortcut)
        .onAppear { engine.scan() }
        .onDisappear { filterText = "" }
        .onChange(of: engine.isScanning) { _, isScanning in
            guard !isScanning else { return }
            initCollapsedKinds()
        }
    }

    /// Invisible ⌘⌫ shortcut (PID-50.7): kills the sole *visible* safe row when
    /// exactly one is shown. There's no row-selection mechanism (arrow traversal is
    /// deliberately out of scope), so a single safe row is the only unambiguous
    /// target — `.disabled` gates the shortcut to `safeItems.count == 1`, making it
    /// inert otherwise. Hosted in `.background` so it contributes no layout (the
    /// popover's fixed width / height-driven sizing stays intact, per PID-040).
    private var soleSafeKillShortcut: some View {
        Button("") {
            guard let sole = sweepableSafeItems.first else { return }
            KillService.kill(sole, containerOwners: engine.containerOwners) { outcome in
                engine.recordCleaned(sole, outcome: outcome)
                engine.scan()
            }
        }
        .keyboardShortcut(.delete, modifiers: .command)
        .disabled(sweepableSafeItems.count != 1)
        .opacity(0)
        .accessibilityHidden(true)
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
                case .cleaned:    break // live-bound to the clean log; nothing to refresh
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(selectedTab == .cleaned)
            .help(refreshHelp)
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

    /// Tooltip for the shared header refresh, tracking the active tab. The Cleaned
    /// tab is live-bound to the clean log, so its refresh is disabled (no action).
    private var refreshHelp: String {
        switch selectedTab {
        case .processes:  return "Rescan (restores hidden items)"
        case .containers: return "Refresh containers"
        case .cleaned:    return "Nothing to refresh"
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("Processes").tag(Tab.processes)
            Text("Containers").tag(Tab.containers)
            Text("Cleaned").tag(Tab.cleaned)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// Live quick-filter for the Processes tab (PID-50.5): a plain text field that
    /// narrows the visible rows by `matchesFilter`. Clears via the trailing ✕ or on
    /// popover close. Styled to match the popover's caption aesthetic.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption2).foregroundStyle(.secondary)
            TextField("Filter by command, project, or port", text: $filterText)
                .textFieldStyle(.plain)
                .font(.caption)
            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear filter")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom, 6)
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
                if safeItems.isEmpty && reviewItems.isEmpty {
                    // Only reachable with an active filter (content renders only when
                    // `engine.items` is non-empty), so this is the "no matches" state.
                    Text("No processes match \u{201C}\(filterText)\u{201D}.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                // Count / reclaimable / sweep all track the *sweepable* set (protected
                // rows excluded), though the rows below still list every safe item.
                Text("Safe to clean (\(sweepableSafeItems.count))")
                    .font(.subheadline).bold()
                Text("~\(ramString(safeReclaimableKB)) reclaimable")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clean all") {
                    let killed = sweepableSafeItems
                    KillService.kill(killed, containerOwners: engine.containerOwners) { outcomes in
                        engine.recordCleaned(killed, outcomes: outcomes)
                        engine.scan()
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(sweepableSafeItems.isEmpty)
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
                        collapsedKinds.toggle(kind)
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
        // Custom-rule matches share one "Custom rules" group header, so the row
        // itself carries the friendly per-rule label as its identity. (PID-54.3)
        if item.kind == .custom, let label = item.customLabel { return label }
        return engine.cwds[item.pid]?.label ?? item.displayPath
    }

    private func row(_ item: ProcessItem) -> some View {
        let isOld = item.elapsed >= engine.elapsedThreshold
        let isExpanded = expandedPIDs.contains(item.pid)
        // Protection is only meaningful for Safe rows (only they're bulk-swept), so the
        // 🔒 badge + lock toggle are gated there (PID-54.4).
        let protectable = item.bucket == .safe && engine.cwds[item.pid] != nil
        let protected = item.bucket == .safe && isProtected(item)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if protected {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 8)
                        .help("Protected — kept out of \u{201C}Clean all\u{201D}")
                } else {
                    Circle()
                        .fill(riskColor(item.riskTier))
                        .frame(width: 8, height: 8)
                }
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
                    expandedPIDs.toggle(item.pid)
                } label: {
                    Image(systemName: isExpanded ? "info.circle.fill" : "info.circle")
                }
                .buttonStyle(.borderless)
                .help("Why is this here?")
                if protectable {
                    Button {
                        toggleProtected(item)
                    } label: {
                        Image(systemName: protected ? "lock.fill" : "lock.open")
                    }
                    .buttonStyle(.borderless)
                    .help(protected ? "Un-protect this project"
                                    : "Protect: keep this project out of \u{201C}Clean all\u{201D}")
                }
                Button {
                    engine.dismiss(item.pid)
                } label: {
                    Image(systemName: "eye.slash")
                }
                .buttonStyle(.borderless)
                .help("Ignore for session")
                Button {
                    KillService.kill(item, containerOwners: engine.containerOwners) { outcome in
                        engine.recordCleaned(item, outcome: outcome)
                        engine.scan()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Kill PID \(item.pid)")
            }
            if isExpanded {
                reasoningBlock(item: item, isOld: isOld)
                    // On-demand open-files fetch (PID-52.3): fires whenever the inspector
                    // appears, decoupled from the ⓘ toggle; the engine caches per session.
                    .onAppear { engine.loadOpenFiles(for: item.pid) }
            }
        }
        .contextMenu { rowContextMenu(item) }
    }

    /// Right-click affordances for a row (PID-50.2): clipboard copies + reveal the
    /// working directory in Finder. Pasteboard / NSWorkspace only — no shell-out.
    @ViewBuilder
    private func rowContextMenu(_ item: ProcessItem) -> some View {
        Button("Copy PID") { copyToPasteboard(String(item.pid)) }
        Button("Copy command line") { copyToPasteboard(item.command) }
        Button("Copy `kill \(item.pid)`") { copyToPasteboard("kill \(item.pid)") }
        // Omitted when the cwd can't be resolved (graceful degrade, like the other
        // provenance hints) — nothing to reveal.
        if let cwd = engine.cwds[item.pid] {
            Button("Reveal working directory in Finder") {
                let path = (cwd.fullPath as NSString).expandingTildeInPath
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
        }
    }

    /// Replace the general pasteboard contents with `string` (PID-50.2).
    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func reasoningBlock(item: ProcessItem, isOld: Bool) -> some View {
        // Full ancestor chain to launchd (PID-52.2): walks the whole process table,
        // so it names non-stray shells / login that `ScanCore.parentCommand` couldn't.
        let ancestors = AncestryResolver.ancestorChain(ofPPID: item.ppid, in: engine.processTable)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if !item.hasTTY { criterionTag("no tty") }
                if item.isOrphan { criterionTag("orphan") }
                if isOld { criterionTag("old") }
            }
            // Idle-dev-server verdict (PID-55.3): sustained low CPU + old + no tty +
            // a dev-mode flag. Advisory reasoning line only — rendered when the signal
            // fires, absent otherwise (graceful degrade, like the provenance hints);
            // never touches the risk dot / bucket / kill bar.
            if engine.isIdleDevServer(item) {
                Text("idle dev server — sustained low CPU across recent scans")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("tty \(item.tty)  ·  ppid \(item.ppid)  ·  age \(ageString(item.elapsed))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
            // Full command line (PID-52.2): promoted from the row's `.help` tooltip to a
            // visible, wrapped line — the inspector is where the complete detail lives.
            Text(item.command)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
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
            if !ancestors.isEmpty {
                Text("child of \(ancestors.joined(separator: " ← "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let owner = engine.containerOwners[item.pid] {
                Text("owned by container \(owner)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            // On-demand open files + sockets (PID-52.3): fetched lazily when this block
            // appears (see `.onAppear` in `row`), cached per session. Rendered only once
            // resolved and non-empty — a process with nothing to show adds no lines
            // (graceful degrade, like the other hints).
            if let list = engine.openFiles[item.pid], !list.files.isEmpty {
                Text("open files")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()
                ForEach(Array(list.files.enumerated()), id: \.offset) { _, file in
                    Text(file.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospaced()
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if list.overflow > 0 {
                    Text("+\(list.overflow) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

    private var safeItems: [ProcessItem] { engine.items.filter { $0.bucket == .safe && matchesFilter($0) } }
    private var reviewItems: [ProcessItem] { engine.items.filter { $0.bucket == .needsReview && matchesFilter($0) } }

    /// The safe rows that "Clean all" (and the ⌘⌫ shortcut) actually sweep — safe items
    /// minus any the user has protected (PID-54.4). Protected rows stay *listed* in the
    /// Safe section (badged 🔒) but are excluded from the bulk sweep, the section count,
    /// and the reclaimable total; their individual kill button still works.
    private var sweepableSafeItems: [ProcessItem] { safeItems.filter { !isProtected($0) } }

    /// True when `item`'s resolved working directory sits under any protected project
    /// tree. Delegates to the engine-side SSOT (`ScanEngine.isProtected`, PID-58.2) so
    /// the popover and the headless sweep can't drift; still reactive (reads the
    /// `@Published` `cwds` + `protectedProjects`) so toggling a lock updates instantly.
    private func isProtected(_ item: ProcessItem) -> Bool {
        engine.isProtected(item)
    }

    /// Toggle protection for `item`'s project. Protecting seeds the row's project root
    /// (falling back to its exact cwd outside a repo); un-protecting removes every
    /// protected entry that currently covers this row, so one click reliably unlocks it.
    private func toggleProtected(_ item: ProcessItem) {
        guard let cwd = engine.cwds[item.pid] else { return }
        if isProtected(item) {
            engine.protectedProjects.removeAll { CwdResolver.isUnderPrefix(cwd.fullPath, $0) }
        } else {
            engine.protectedProjects.append(cwd.projectRoot ?? cwd.fullPath)
        }
    }

    /// Quick-filter predicate (PID-50.5): an empty query passes everything; otherwise a
    /// case-insensitive substring match against the command line, the row's
    /// project/provenance label (`rowDescriptor`), or any listening port number.
    /// Folded into `safeItems` / `reviewItems` so the section counts, "Clean all" scope,
    /// and the reclaimable-footprint header all track the filtered set.
    private func matchesFilter(_ item: ProcessItem) -> Bool {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if item.command.localizedCaseInsensitiveContains(query) { return true }
        if rowDescriptor(item).localizedCaseInsensitiveContains(query) { return true }
        if let ports = engine.listeningPorts[item.pid],
           ports.contains(where: { String($0).contains(query) }) {
            return true
        }
        return false
    }

    /// Total resident memory the *sweepable* safe processes would free if cleaned —
    /// protected rows are excluded, matching the "Clean all" scope (PID-54.4).
    private var safeReclaimableKB: Int { sweepableSafeItems.reduce(0) { $0 + $1.rssKB } }

    private func grouped(_ items: [ProcessItem]) -> [(ProcessKind, [ProcessItem])] {
        ProcessKind.allCases.compactMap { kind in
            let matches = items.filter { $0.kind == kind }
            // Order each group alphabetically by the provenance/project label so the
            // list stays stable across scans instead of leaking `engine.items` scan
            // order (PID-50.3). `pid` breaks ties (same descriptor) for full determinism.
            let sorted = matches.sorted {
                switch rowDescriptor($0).localizedCaseInsensitiveCompare(rowDescriptor($1)) {
                case .orderedAscending:  return true
                case .orderedDescending: return false
                case .orderedSame:       return $0.pid < $1.pid
                }
            }
            return sorted.isEmpty ? nil : (kind, sorted)
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

private extension Set {
    /// Insert `member` if absent, remove it if present — the one-line
    /// equivalent of the `contains ? remove : insert` toggle shape.
    mutating func toggle(_ member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}
