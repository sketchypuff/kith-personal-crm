import SwiftData
import SwiftUI

/// The private CloudKit sync toggle (Settings §7), placed in the Other
/// section. Flipping it rebuilds the `ModelContainer` through the app-level
/// coordinator: the row shows a transient Updating… state and is
/// non-interactive until the store has reopened, and a failed reopen rolls
/// the switch back with a relaunch prompt.
struct SyncRows: View {
    let iCloudAvailable: Bool

    @Environment(ModelContainerCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    /// Mirrors the coordinator's *actual* state, which can lag the stored
    /// preference when CloudKit was unavailable at launch.
    @State private var syncOn = AppPreferences.syncEnabled
    @State private var isUpdating = false
    @State private var showsRebuildFailure = false

    var body: some View {
        Toggle(isOn: $syncOn) {
            HStack {
                Text("Sync with iCloud")
                Spacer()
                if isUpdating {
                    ProgressView()
                    Text("Updating…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!iCloudAvailable || isUpdating)
        .task {
            syncOn = coordinator.syncEnabled
        }
        .onChange(of: syncOn) { _, enabled in
            syncDidChange(enabled)
        }
        .alert("Couldn't update sync", isPresented: $showsRebuildFailure) {
        } message: {
            Text("Kith couldn't reopen your data with the new setting, so nothing was changed. Please relaunch Kith and try again.")
        }
    }

    // MARK: - Actions

    /// Re-entry guard: ignores flips while a rebuild is in flight, and the
    /// echo when a failed rebuild snaps the switch back.
    private func syncDidChange(_ enabled: Bool) {
        guard !isUpdating, enabled != coordinator.syncEnabled else { return }
        isUpdating = true
        Task {
            await applySync(enabled)
        }
    }

    private func applySync(_ enabled: Bool) async {
        defer { isUpdating = false }
        // Let the Updating… state paint before the synchronous rebuild.
        try? await Task.sleep(for: .milliseconds(300))

        let actions = SettingsActions(context: modelContext, notifications: NotificationScheduler())
        guard actions.setSyncEnabled(enabled, coordinator: coordinator) else {
            syncOn = coordinator.syncEnabled
            showsRebuildFailure = true
            return
        }
    }
}
