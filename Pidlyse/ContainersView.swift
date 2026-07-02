import SwiftUI
import PidlyseCore

/// The Containers tab of the popover: a list of running Docker containers
/// (name / image / status / ports, plus a one-shot CPU/memory sample) with
/// per-row stop and remove buttons.
/// State is local `@State` — there's no timer/persistence lifecycle to own, so
/// the list loads off-main on appear (and on the shared header's `↻`, via
/// `refreshToken`) and re-renders from the refreshed `[Container]` that every
/// `DockerService` call delivers on the main queue. Stats arrive from a
/// separate `docker stats --no-stream` shell-out (~1-2 s) and fill in when
/// ready, joined onto rows by container ID. All `docker` access stays
/// in `DockerService`; this view never shells out. Never auto-acts — stop and
/// remove only run on an explicit button click (per CLAUDE.md).
struct ContainersView: View {
    /// Bumped by `MenuBarView`'s shared header refresh while this tab is active;
    /// each change triggers a reload so the one `↻` serves both tabs.
    let refreshToken: Int

    @State private var containers: [Container] = []
    @State private var stats: [String: ContainerStats] = [:]
    @State private var loading = false

    var body: some View {
        Group {
            if !DockerService.isInstalled {
                empty("Docker isn’t installed.")
            } else if containers.isEmpty {
                empty(loading ? "Loading…" : "No running containers.")
            } else {
                list
            }
        }
        .frame(height: 360)
        .onAppear(perform: reload)
        .onChange(of: refreshToken) { reload() }
    }

    // MARK: - Sections

    private func empty(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(containers) { row($0) }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func row(_ container: Container) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.caption).bold()
                    .lineLimit(1).truncationMode(.middle)
                Text(container.image)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                if !container.ports.isEmpty {
                    Text(container.ports)
                        .font(.caption2).foregroundStyle(.tertiary).monospaced()
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(container.status)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                if let sample = stats[container.id] {
                    Text("\(sample.cpu) · \(sample.memory)")
                        .font(.caption2).foregroundStyle(.tertiary).monospaced()
                        .lineLimit(1)
                }
            }
            Button {
                DockerService.stop(container.id) {
                    containers = $0
                    reloadStats()
                }
            } label: {
                Image(systemName: "stop.circle")
            }
            .buttonStyle(.borderless)
            .help("Stop \(container.name)")
            Button {
                DockerService.remove(container.id) {
                    containers = $0
                    reloadStats()
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Stop and remove \(container.name)")
        }
    }

    // MARK: - Loading

    private func reload() {
        loading = true
        DockerService.list {
            containers = $0
            loading = false
        }
        reloadStats()
    }

    /// One-shot stats refetch — on load/refresh alongside `docker ps`, and
    /// after stop/remove so surviving rows don't keep a stale sample.
    private func reloadStats() {
        DockerService.stats { stats = $0 }
    }
}
