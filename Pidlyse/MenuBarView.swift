import SwiftUI
import PidlyseCore

/// The popover content: a strays-first list bound to `ScanEngine` (PID-086.4).
/// "Likely strays" leads, sub-headed by the stray verdict's reason, with one "Clean
/// all" over the engine's sweep set; in-use processes fold into one collapsed
/// "Running" section grouped by project. Every row also carries a kill button.
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
    /// Whether the folded "Running" section is open. Starts collapsed: in-use
    /// processes aren't what the popover is for (PID-086.4).
    @State private var isRunningExpanded = false
    /// Live filter for the Processes tab. Session-scoped: the hosting controller is
    /// reused across popover opens (see `AppDelegate`), so `@State` persists — the
    /// `.onDisappear` below clears it so each open starts unfiltered.
    @State private var filterText = ""
    /// The last popover "Clean all" tally, shown under the strays header for
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
        .background(soleStrayKillShortcut)
        .onAppear { engine.scan() }
        .onDisappear { filterText = "" }
    }

    /// Invisible ⌘⌫ shortcut (PID-50.7): kills the sole *visible* sweepable stray
    /// when exactly one is shown. There's no row-selection mechanism (arrow traversal
    /// is deliberately out of scope), so a single sweepable row is the only
    /// unambiguous target — `.disabled` gates the shortcut to exactly one, making it
    /// inert otherwise. Hosted in `.background` so it contributes no layout (the
    /// popover's fixed width / height-driven sizing stays intact, per PID-040).
    private var soleStrayKillShortcut: some View {
        Button("") {
            guard let sole = sweepableStrayItems.first else { return }
            engine.kill([sole])
        }
        .keyboardShortcut(.delete, modifiers: .command)
        .disabled(sweepableStrayItems.count != 1)
        .opacity(0)
        .accessibilityHidden(true)
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
        Text("No dev processes running.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let noMatch = strayRows.isEmpty && runningRows.isEmpty && !filterText.isEmpty
                if noMatch {
                    Text("No processes match \u{201C}\(filterText)\u{201D}.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // The Clean-all report stays up even when the filter hides every row.
                if !noMatch || cleanReport != nil { straysSection }
                if !runningRows.isEmpty { runningSection }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // Fixed height so the window opens to a usable size instead of
        // collapsing to the ScrollView's minimum (which hid the rows).
        .frame(height: 360)
    }

    /// The reasons "Likely strays" is sub-headed by, in display order.
    private static let strayReasons: [StrayVerdict] = [.sessionEnded, .idle, .duplicate]

    private var straysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Likely strays (\(strayItems.count))")
                    .font(.subheadline).bold()
                // Reclaimable and the sweep track the *sweepable* strays (not high-risk,
                // protected, or unkillable), though every stray stays listed below.
                if !sweepableStrayItems.isEmpty {
                    Text("~\(ramString(reclaimableKB)) reclaimable")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clean all") {
                    engine.kill(sweepableStrayItems) { showCleanReport($0) }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(sweepableStrayItems.isEmpty)
            }
            if let cleanReport {
                Text(cleanReport.summaryLine)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if strayRows.isEmpty {
                Text("No likely strays.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Self.strayReasons, id: \.self) { reason in
                let rows = sortedByName(strayRows.filter { engine.verdict($0) == reason })
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reason.label)
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(rows) { row($0) }
                    }
                }
            }
        }
    }

    /// In-use processes folded into one header (PID-086.4); expanding lists them under
    /// per-repo sub-headers, so the rows show only their subfolder, if any.
    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isRunningExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isRunningExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("Running")
                        .font(.subheadline).bold()
                    Text(runningSummary)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            if isRunningExpanded {
                ForEach(byProject(runningRows), id: \.0) { project, rows in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project)
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(rows) { row($0, showsProject: false) }
                    }
                }
            }
        }
    }

    /// `· 12 in use across 4 projects` — projects are repos (`bidviz` and
    /// `bidviz/frontend` are one); rows with no resolved project count toward the
    /// processes but not the projects.
    private var runningSummary: String {
        let projects = Set(runningItems.compactMap(projectName)).count
        let across = projects == 0 ? "" : " across \(projects) project\(projects == 1 ? "" : "s")"
        return "\u{00B7} \(runningItems.count) in use\(across)"
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

    /// The repo part of `projectLabel` (`bidviz` for `bidviz/frontend`) — the Running
    /// section's project grouping key (PID-086.4).
    private func projectName(_ item: ProcessItem) -> String? {
        projectLabel(item).map { String($0.prefix { $0 != "/" }) }
    }

    /// The subfolder part of `projectLabel` (`frontend` for `bidviz/frontend`); `nil`
    /// at the repo root.
    private func subfolder(_ item: ProcessItem) -> String? {
        guard let label = projectLabel(item), let slash = label.firstIndex(of: "/") else { return nil }
        return String(label[label.index(after: slash)...])
    }

    /// Group row (PID-62.4): how many processes the one kill covers. Trails the name.
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
    /// project (just its subfolder under a Running repo sub-header), the grey PID, then the
    /// kill control. Clicking the row toggles the inspector, which holds the verdict,
    /// CPU / RAM / age; protect and ignore live in the context menu.
    private func row(_ item: ProcessItem, showsProject: Bool = true) -> some View {
        let isOld = item.elapsed >= engine.elapsedThreshold
        let protected = isProtectable(item) && isProtected(item)
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
                Text(item.displayName)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .help(item.command)
                groupCount(item)
                if let project = showsProject ? projectLabel(item) : subfolder(item) {
                    Text(project)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                        .help(engine.cwds[item.pid]?.fullPath ?? project)
                }
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

    /// Show a Clean-all tally under the strays header for `cleanReportLinger`.
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
        // Protection is only meaningful for rows "Clean all" can take, so the toggle is
        // gated there (PID-54.4, PID-086.4).
        if isProtectable(item) && engine.cwds[item.pid] != nil {
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
            // Why the row sits where it does (PID-086.4): the stray verdict's one
            // sentence, from core (`StrayVerdict.explanation`).
            let verdict = engine.verdict(item)
            Text("\(verdict.label) — \(verdict.explanation)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var strayItems: [ProcessItem] { engine.items.filter { engine.verdict($0).isStray && matchesFilter($0) } }
    private var runningItems: [ProcessItem] { engine.items.filter { !engine.verdict($0).isStray && matchesFilter($0) } }

    /// What each section renders: its live items plus any verified-gone rows still
    /// lingering to show their verdict (PID-62.5), placed by the verdict they had when
    /// killed. Counts, the sweep set and the reclaimable total stay on the live items.
    private var strayRows: [ProcessItem] { strayItems + departedRows(stray: true) }
    private var runningRows: [ProcessItem] { runningItems + departedRows(stray: false) }

    /// Lingering gone rows for one section, minus any PID a scan has already re-listed
    /// (a recycled PID) so row IDs stay unique.
    private func departedRows(stray: Bool) -> [ProcessItem] {
        let live = Set(engine.items.map(\.pid))
        return engine.departedItems.values.filter {
            engine.verdict($0).isStray == stray && !live.contains($0.pid) && matchesFilter($0)
        }
    }

    /// The strays that "Clean all" (and the ⌘⌫ shortcut) actually sweep — the visible
    /// likely strays the engine's `isSweepable` admits (not high-risk, protected
    /// (PID-54.4), registered-port-bound (PID-088), unkillable (PID-62.3), or
    /// mid-kill). The rest stay *listed*, badged,
    /// but are excluded from the sweep and the reclaimable total. Delegating the
    /// predicate keeps the popover and the headless sweep from drifting; still
    /// reactive (reads `@Published` state).
    private var sweepableStrayItems: [ProcessItem] { strayItems.filter { engine.isSweepable($0) } }

    /// Whether protecting `item` would change anything: only rows "Clean all" can take
    /// — any but high-risk ones (PID-086.2) — are kept out of it by a lock.
    private func isProtectable(_ item: ProcessItem) -> Bool {
        item.riskTier != .high
    }

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
    /// Folded into `strayItems` / `runningItems` so the section counts, "Clean all"
    /// scope, and the reclaimable-footprint header all track the filtered set.
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

    /// Total resident memory the sweepable strays would free if cleaned — matching
    /// the "Clean all" scope (PID-54.4, PID-086.4).
    private var reclaimableKB: Int { sweepableStrayItems.reduce(0) { $0 + $1.rssKB } }

    /// `items` alphabetically by name, then project, so the list stays stable across
    /// scans instead of leaking `engine.items` scan order (PID-50.3, PID-086.3).
    /// `pid` breaks ties for full determinism. Keys are computed once per row, not
    /// per comparison.
    private func sortedByName(_ items: [ProcessItem]) -> [ProcessItem] {
        items
            .map { (item: $0, name: $0.displayName, project: projectLabel($0) ?? "") }
            .sorted {
                let byName = $0.name.localizedCaseInsensitiveCompare($1.name)
                if byName != .orderedSame { return byName == .orderedAscending }
                let byProject = $0.project.localizedCaseInsensitiveCompare($1.project)
                if byProject != .orderedSame { return byProject == .orderedAscending }
                return $0.item.pid < $1.item.pid
            }
            .map(\.item)
    }

    /// The Running section's per-repo groups (PID-086.4): repos alphabetically, rows
    /// with no resolved project last under "No project".
    private func byProject(_ items: [ProcessItem]) -> [(String, [ProcessItem])] {
        let groups = Dictionary(grouping: items) { projectName($0) }
        let named = groups.keys.compactMap { $0 }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { ($0, sortedByName(groups[$0] ?? [])) }
        guard let unresolved = groups[nil] else { return named }
        return named + [("No project", sortedByName(unresolved))]
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
