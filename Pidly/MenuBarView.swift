import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Pidly")
                .font(.headline)
            Text("No stray processes detected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280)
    }
}
