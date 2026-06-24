import SwiftUI

@main
struct PidlyApp: App {
    @StateObject private var engine = ScanEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: engine)
        } label: {
            MenuBarIconView(engine: engine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(engine: engine)
        }
    }
}

/// Menu bar icon: spinner while scanning, filled cpu + count badge when strays
/// exist, outline cpu when clean. Badge is red for safe-to-kill count, yellow
/// when only review items exist.
private struct MenuBarIconView: View {
    @ObservedObject var engine: ScanEngine

    private var safeCount: Int { engine.items.filter { $0.bucket == .safe }.count }
    private var reviewCount: Int { engine.items.filter { $0.bucket == .needsReview }.count }

    var body: some View {
        Group {
            if engine.isScanning {
                Image(systemName: "arrow.2.circlepath")
            } else if safeCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "cpu.fill")
                    Text("\(safeCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }
            } else if reviewCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "cpu.fill")
                    Text("\(reviewCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            } else {
                Image(systemName: "cpu")
            }
        }
    }
}
