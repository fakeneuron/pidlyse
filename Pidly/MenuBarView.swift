import SwiftUI

/// The popover content: a live two-section list (Safe / Needs Review) bound to
/// `ScanEngine`, with rows grouped by `kind`. Safe items can be swept with one
/// "Clean all safe" click; every row also carries an individual kill button.
/// Kills route through `KillService` (SIGTERM → 2 s → SIGKILL) and trigger a
/// rescan. Never auto-kills — every kill is an explicit click (per CLAUDE.md).
struct MenuBarView: View {
    @ObservedObject var engine: ScanEngine
    @State private var expandedPIDs: Set<Int32> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if engine.items.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(width: 320)
        .onAppear { engine.scan() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Pidly").font(.headline)
            Spacer()
            Button {
                engine.rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Rescan (restores hidden items)")
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                    KillService.kill(safeItems) { engine.scan() }
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

    /// Render `items` grouped under a per-kind header (collapses noisy clusters
    /// like Docker's ~10 helpers under one heading). `ProcessKind.allCases`
    /// gives a stable group order.
    private func groups(for items: [ProcessItem]) -> some View {
        ForEach(grouped(items), id: \.0) { kind, rows in
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.label)
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(rows) { row($0) }
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
                    Text(item.displayPath)
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
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
                    KillService.kill(item) { engine.scan() }
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
