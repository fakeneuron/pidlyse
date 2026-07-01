import SwiftUI
import PidlyseCore

/// The Cleaned tab of the popover (PID-53.3): the persistent-value view over the
/// confirmed-clean log that [[PID-53.2]] persists. A value-stats strip over a
/// rolling week (cleaned this week / RAM reclaimed / top stray kinds) sits above a
/// newest-first "Recently cleaned" list. Binds directly to the `CleanLogStore`
/// (`@ObservedObject`) so it re-renders when a kill appends an event; all
/// aggregation is the pure `PidlyseCore.CleanLog.stats` (this view never persists).
struct CleanedView: View {
    /// The app-side clean log, owned by `ScanEngine` and passed down. Observed here
    /// (rather than reached through `engine`) so `events` changes refresh this tab.
    @ObservedObject var store: CleanLogStore

    /// Rolling window for the headline value stats — "this week" = 7 days.
    private static let statsWindow: TimeInterval = 7 * 86400
    /// Cap on the Recently-cleaned rows rendered, to bound the view against the
    /// store's 1000-event retention. Newest are kept.
    private static let recentDisplayCap = 50

    var body: some View {
        Group {
            if store.events.isEmpty {
                empty("No cleaned processes yet.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        statsStrip
                        recentSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 360)
    }

    // MARK: - Derived data

    /// Value stats over the rolling week — count, RAM reclaimed, top kinds.
    private var stats: CleanLog.Stats {
        CleanLog.stats(from: store.events, now: Date(), window: Self.statsWindow)
    }

    /// Newest-first, display-capped slice of the log for the Recently-cleaned list.
    private var recentEvents: [CleanEvent] {
        Array(store.events.reversed().prefix(Self.recentDisplayCap))
    }

    // MARK: - Sections

    private func empty(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private var statsStrip: some View {
        let s = stats
        return VStack(alignment: .leading, spacing: 6) {
            Text("This week")
                .font(.subheadline).bold()
            HStack(spacing: 6) {
                Text("\(s.count) cleaned")
                Text("·").foregroundStyle(.tertiary)
                Text("~\(ramString(s.ramReclaimedKB)) reclaimed")
            }
            .font(.caption).foregroundStyle(.secondary)
            if !s.topKinds.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(s.topKinds.prefix(3).enumerated()), id: \.offset) { _, kc in
                        kindChip(kc)
                    }
                }
            }
        }
    }

    /// One "kind ×N" chip in the top-kinds row. Maps the stored `ProcessKind`
    /// rawValue back to its display label, falling back to the raw string if the
    /// enum evolved and no longer knows the case.
    private func kindChip(_ kc: CleanLog.KindCount) -> some View {
        let label = ProcessKind(rawValue: kc.kind)?.label ?? kc.kind
        return Text("\(label) ×\(kc.count)")
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently cleaned")
                .font(.subheadline).bold()
            ForEach(Array(recentEvents.enumerated()), id: \.offset) { _, event in
                recentRow(event)
            }
        }
    }

    private func recentRow(_ event: CleanEvent) -> some View {
        let label = ProcessKind(rawValue: event.kind)?.label ?? event.kind
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).bold()
                Text(event.projectLabel)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(ramString(event.rssKB))
                .font(.caption2).foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
            Text(relativeAge(event.timestamp))
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Formatting

    /// KB → "N MB" / "N KB", matching the Processes tab's footprint formatting.
    private func ramString(_ kb: Int) -> String {
        let mb = kb / 1024
        return mb > 0 ? "\(mb) MB" : "\(kb) KB"
    }

    /// Native relative "…ago" string (e.g. "2h ago", "yesterday") for the clean time.
    private func relativeAge(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
