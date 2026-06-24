import SwiftUI

@main
struct PidlyApp: App {
    var body: some Scene {
        MenuBarExtra("Pidly", systemImage: "cpu") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
