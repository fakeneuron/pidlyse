import SwiftUI

@main
struct PidlyApp: App {
    @StateObject private var engine = ScanEngine()

    var body: some Scene {
        MenuBarExtra("Pidly", systemImage: "cpu") {
            MenuBarView(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}
