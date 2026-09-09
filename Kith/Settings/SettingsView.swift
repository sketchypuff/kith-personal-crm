import SwiftUI

/// Placeholder until the Settings spec is implemented.
struct SettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "gearshape",
            description: Text("Defaults, notifications, lock, and sync arrive with the Settings flow.")
        )
        .navigationTitle("Settings")
    }
}
