import SwiftUI
import PidlyseCore

/// The popover content: a live two-section list (Safe / Needs Review) bound to
/// `ScanEngine`, with rows grouped by `kind`. Safe items can be swept with one
/// "Clean all safe" click; every row also carries an individual kill button.
/// Kills route through `ScanEngine.kill` (SIGTERM → 2 s → SIGKILL, verified, then a
/// rescan), and each killed row shows its phase in place of the button (PID-62.5).
/// Never auto-kills — every kill is an explicit click (per AGENTS.md).
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
    /// The last popover "Clean all" tally, shown under the Safe header for
    /// `cleanReportLinger` (PID-62.5). `cleanReportToken` keeps an older clear
    /// from wiping a newer report.
    @State private var cleanReport: KillReport?
    @State private var cleanReportToken = 0
    private static let cleanReportLinger: TimeInterval = 8

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
                // Kill feedback (lingering rows, the Clean-all line) keeps the list up
                // briefly after the last process goes (PID-62.5).
                if engine.items.isEmpty && engine.departedItems.isEmpty && cleanReport == nil {
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
            engine.kill([sole])
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
                if safeRows.isEmpty && reviewRows.isEmpty && !filterText.isEmpty {
                    Text("No processes match \u{201C}\(filterText)\u{201D}.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !safeRows.isEmpty || cleanReport != nil { safeSection }
                if !reviewRows.isEmpty { reviewSection }
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
                    engine.kill(sweepableSafeItems) { showCleanReport($0) }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(sweepableSafeItems.isEmpty)
            }
            if let cleanReport {
                Text(cleanReport.summaryLine)
                    .font(.caption).foregroundStyle(.secondary)
            }
            groups(for: safeRows)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Needs review (\(reviewItems.count))")
                .font(.subheadline).bold()
            groups(for: reviewRows)
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

    /// The git project the process runs in (`bidviz` / `bidviz/frontend`), shown after
    /// the name — the owner hint PID-038 targets. `nil` when no cwd resolves: the
    /// name already says what the process is (PID-086.3).
    private func projectLabel(_ item: ProcessItem) -> String? {
        engine.cwds[item.pid]?.label
    }

    /// Whether the row shows its name: not when it only repeats the kind-group header
    /// it sits under (`playwright-mcp` under "playwright-mcp"), unless there is no
    /// project to lead with instead.
    private func showsName(_ item: ProcessItem) -> Bool {
        item.displayName.caseInsensitiveCompare(item.kind.label) != .orderedSame
            || projectLabel(item) == nil
    }

    /// Group row (PID-62.4): how many processes the one kill covers. Trails the
    /// row's leading label — the name, or the project when the name is hidden.
    @ViewBuilder
    private func groupCount(_ item: ProcessItem) -> some View {
        if !item.members.isEmpty {
            Text("\u{00D7}\(item.members.count + 1)")
                .font(.caption2).foregroundStyle(.secondary)
                .layoutPriority(1)
                .help("\(item.members.count + 1) processes that live and die together")
        }
    }

    /// One dense line (PID-086.3): risk dot / 🔒, the descriptive name (never
    /// truncated — the project gives way first, and an overlong name wraps), the
    /// project, the grey PID, then the kill control. Clicking the row toggles the
    /// inspector, which holds CPU / RAM / age; protect and ignore live in the
    /// context menu.
    private func row(_ item: ProcessItem) -> some View {
        let isOld = item.elapsed >= engine.elapsedThreshold
        let protected = item.bucket == .safe && isProtected(item)
        let killability = engine.killability(item)
        let killPhase = engine.killPhase(for: item)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
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
                if showsName(item) {
                    Text(item.displayName)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .help(item.command)
                    groupCount(item)
                }
                if let project = projectLabel(item) {
                    // Leads the row (primary) when the name is hidden.
                    Text(project)
                        .font(showsName(item) ? .caption2 : .caption)
                        .foregroundStyle(showsName(item) ? .secondary : .primary)
                        .lineLimit(1).truncationMode(.tail)
                        .help(engine.cwds[item.pid]?.fullPath ?? project)
                }
                if !showsName(item) { groupCount(item) }
                Spacer(minLength: 4)
                // `Text(verbatim:)` (PID-070): a plain string interpolation here
                // routes the PID through `Text`'s localized-number formatting,
                // which inserts a thousands separator and can wrap.
                Text(verbatim: "\(item.pid)")
                    .font(.caption2).monospaced().foregroundStyle(.tertiary)
                    .fixedSize()
                    .help("PID \(item.pid)")
                // A kill in flight or just answered shows its phase where the button
                // was (PID-62.5). Otherwise, a kill button is a promise the process
                // will die and stay dead (PID-62.3). Where we can't make it —
                // foreign-owned, or a known respawner — the button is replaced by a
                // badge carrying the explanation, rather than left as a dead end.
                if let killPhase {
                    killPhaseLabel(killPhase)
                } else if let explanation = killability.explanation {
                    // A bare Image sat in the same icon-button row as the other buttons and
                    // read as one — the operator clicked expecting an action. Route the
                    // click to the same inspector toggle the row uses (PID-070, PID-086.3).
                    Button {
                        expandedPIDs.toggle(item.pid)
                    } label: {
                        Image(systemName: killabilityBadge(killability))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(explanation)
                } else {
                    Button {
                        engine.kill([item])
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Kill PID \(item.pid)")
                }
            }
            // The whole line toggles the inspector ("Why is this here?"); the kill
            // and badge buttons keep their own clicks.
            .contentShape(Rectangle())
            .onTapGesture { expandedPIDs.toggle(item.pid) }
            .help("Click for details")
            if expandedPIDs.contains(item.pid) {
                reasoningBlock(item: item, isOld: isOld, killability: killability)
                    // On-demand open-files fetch (PID-52.3): fires whenever the inspector
                    // appears, decoupled from the row toggle; the engine caches per session.
                    .onAppear { engine.loadOpenFiles(for: item.pid) }
            }
        }
        // A row whose process is gone stays only to show the verdict (PID-62.5).
        .opacity(killPhase?.isDeparted == true ? 0.5 : 1)
        .contextMenu { rowContextMenu(item) }
    }

    /// The kill's phase in place of the ✕ (PID-62.5): a spinner while in flight,
    /// then the verified verdict, with `KillPhase.detail` as the tooltip.
    private func killPhaseLabel(_ phase: KillPhase) -> some View {
        HStack(spacing: 3) {
            if phase == .killing {
                ProgressView().controlSize(.mini)
            }
            Text(phase.label).font(.caption2)
        }
        .foregroundStyle(killPhaseColor(phase))
        .help(phase.detail)
    }

    private func killPhaseColor(_ phase: KillPhase) -> Color {
        switch phase {
        case .gone:                          return .green
        case .respawned:                     return .orange
        case .survived:                      return .red
        case .killing, .unkillable, .skipped: return .secondary
        }
    }

    /// Show a Clean-all tally under the Safe header for `cleanReportLinger`.
    private func showCleanReport(_ report: KillReport) {
        cleanReportToken += 1
        let token = cleanReportToken
        cleanReport = report
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.cleanReportLinger) {
            if cleanReportToken == token { cleanReport = nil }
        }
    }

    /// Right-click affordances for a row (PID-50.2): clipboard copies + reveal the
    /// working directory in Finder. Pasteboard / NSWorkspace only — no shell-out.
    /// Protect and ignore moved here from the row (PID-086.3).
    @ViewBuilder
    private func rowContextMenu(_ item: ProcessItem) -> some View {
        // Protection is only meaningful for Safe rows (only they're bulk-swept), so the
        // toggle is gated there (PID-54.4).
        if item.bucket == .safe && engine.cwds[item.pid] != nil {
            Button(isProtected(item) ? "Un-protect this project"
                                     : "Protect this project (keep out of \u{201C}Clean all\u{201D})") {
                toggleProtected(item)
            }
        }
        Button("Ignore for session") { engine.dismiss(item.pid) }
        Divider()
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

    /// SF Symbol standing in for the kill button on a row we can't honestly kill
    /// (PID-62.3): a no-entry sign for foreign-owned, a cycle for a known respawner.
    private func killabilityBadge(_ killability: Killability) -> String {
        switch killability {
        case .killable:   return "xmark.circle.fill"   // unreachable — the button renders instead
        case .unkillable: return "nosign"
        case .respawner:  return "arrow.triangle.2.circlepath"
        }
    }

    private func reasoningBlock(item: ProcessItem, isOld: Bool, killability: Killability) -> some View {
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
            // Why this row has no kill button (PID-62.3). Same sentence the row badge
            // carries as its tooltip — `Killability.explanation` is the one source —
            // and the same graceful-degrade shape as the line above: rendered when the
            // state applies, absent otherwise.
            if let explanation = killability.explanation {
                Text(explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Resource figures moved off the row (PID-086.3).
            Text(verbatim: "cpu \(String(format: "%.1f%%", item.cpuPercent))  ·  ram \(ramString(item.rssKB))  ·  age \(ageString(item.elapsed))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
            // `Text(verbatim:)` (PID-070/PID-073): plain string interpolation here
            // routes `ppid` through `Text`'s localized-number formatting, which
            // inserts a thousands separator.
            Text(verbatim: "tty \(item.tty)  ·  ppid \(item.ppid)")
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
            // (PID-038) is promoted to the always-visible row instead of a line
            // here — see `projectLabel`.
            if let ports = listeningPorts(item) {
                Text("\(ports.sorted().map { ":\($0)" }.joined(separator: ", ")) listening")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            // The processes folded into this row (PID-62.4) — read-only: the row's one
            // kill covers them all.
            if !item.members.isEmpty {
                Text("group of \(item.members.count + 1) — "
                     + ([item] + item.members).map { "PID \($0.pid) \(memberLabel($0))" }
                        .joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    /// What each section renders: its live items plus any verified-gone rows still
    /// lingering to show their verdict (PID-62.5). Counts, the sweep set and the
    /// reclaimable total stay on the live items alone.
    private var safeRows: [ProcessItem] { safeItems + departedRows(.safe) }
    private var reviewRows: [ProcessItem] { reviewItems + departedRows(.needsReview) }

    /// Lingering gone rows for one bucket, minus any PID a scan has already re-listed
    /// (a recycled PID) so row IDs stay unique.
    private func departedRows(_ bucket: Bucket) -> [ProcessItem] {
        let live = Set(engine.items.map(\.pid))
        return engine.departedItems.values.filter {
            $0.bucket == bucket && !live.contains($0.pid) && matchesFilter($0)
        }
    }

    /// The safe rows that "Clean all" (and the ⌘⌫ shortcut) actually sweep — safe items
    /// minus any the user has protected (PID-54.4) and minus any Pidlyse can't honestly
    /// kill (PID-62.3). Both kinds stay *listed* in the Safe section, badged, but are
    /// excluded from the bulk sweep, the section count, and the reclaimable total.
    /// Delegates the predicate to `ScanEngine.isSweepable` so the popover and the
    /// headless sweep can't drift; still reactive (reads `@Published` state).
    private var sweepableSafeItems: [ProcessItem] { safeItems.filter { engine.isSweepable($0) } }

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
    /// case-insensitive substring match against the command line, the row's name
    /// (`displayName`), its project label, or any listening port number.
    /// Folded into `safeItems` / `reviewItems` so the section counts, "Clean all" scope,
    /// and the reclaimable-footprint header all track the filtered set.
    private func matchesFilter(_ item: ProcessItem) -> Bool {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if item.command.localizedCaseInsensitiveContains(query) { return true }
        if item.displayName.localizedCaseInsensitiveContains(query) { return true }
        if projectLabel(item)?.localizedCaseInsensitiveContains(query) == true { return true }
        if let ports = listeningPorts(item),
           ports.contains(where: { String($0).contains(query) }) {
            return true
        }
        return false
    }

    /// Registered ports any process in the row listens on — the root plus, for a group
    /// row, every member (PID-62.4), since the listener is often a child (`next-server`,
    /// `vite`). `nil` when none.
    private func listeningPorts(_ item: ProcessItem) -> Set<Int>? {
        let ports = ([item] + item.members).reduce(into: Set<Int>()) {
            $0.formUnion(engine.listeningPorts[$1.pid] ?? [])
        }
        return ports.isEmpty ? nil : ports
    }

    /// Short executable name for a group member in the inspector (`sh`, `npm`,
    /// `next-server`) — the first command token's last path component.
    private func memberLabel(_ item: ProcessItem) -> String {
        let first = item.command.split(separator: " ", maxSplits: 1).first.map(String.init) ?? item.command
        return AncestryResolver.compactLabel(first)
    }

    /// Total resident memory the *sweepable* safe processes would free if cleaned —
    /// protected rows are excluded, matching the "Clean all" scope (PID-54.4).
    private var safeReclaimableKB: Int { sweepableSafeItems.reduce(0) { $0 + $1.rssKB } }

    private func grouped(_ items: [ProcessItem]) -> [(ProcessKind, [ProcessItem])] {
        ProcessKind.allCases.compactMap { kind in
            let matches = items.filter { $0.kind == kind }
            // Order each group alphabetically by name, then project, so the list stays
            // stable across scans instead of leaking `engine.items` scan order
            // (PID-50.3, PID-086.3). `pid` breaks ties for full determinism.
            // Keys are computed once per row, not per comparison.
            let sorted = matches
                .map { (item: $0, name: $0.displayName, project: projectLabel($0) ?? "") }
                .sorted {
                    let byName = $0.name.localizedCaseInsensitiveCompare($1.name)
                    if byName != .orderedSame { return byName == .orderedAscending }
                    let byProject = $0.project.localizedCaseInsensitiveCompare($1.project)
                    if byProject != .orderedSame { return byProject == .orderedAscending }
                    return $0.item.pid < $1.item.pid
                }
                .map(\.item)
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
