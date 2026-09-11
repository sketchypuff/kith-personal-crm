import SwiftData
import SwiftUI
import UserNotifications

/// Settings: app-level defaults and machinery in one flat `Form` (Settings
/// §2–§3). Every control is a live `@AppStorage` write; the rows with side
/// effects go through `SettingsActions`. The environment probes the sections
/// depend on (notification permission, lock availability, iCloud) live here
/// and refresh whenever the app comes back to the foreground.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var notificationsDenied = false
    @State private var lockAvailability = LockAuthenticator().availability()
    @State private var iCloudAvailable = ModelContainerCoordinator.isICloudAvailable

    /// The developer card. Presented from the `Form` rather than from inside
    /// `AboutSection`, because a `.sheet` on a `Section` is applied once per
    /// row and the competing presentations dismiss one another instantly.
    @State private var isPresentingDeveloper = false

    /// The tag vocabulary. Hoisted for the same reason as the card above.
    @State private var isPresentingTags = false

    /// The coalesced reschedule pass (§9): every notification-preference
    /// change restarts the timer, so a burst of flips settles into one pass.
    /// Unstructured on purpose — it must survive switching tabs mid-settle.
    @State private var pendingReschedule: Task<Void, Never>?

    private var actions: SettingsActions {
        SettingsActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        Form {
            NotificationDefaultsSection(notificationsDenied: notificationsDenied, onChange: notificationsDidChange)
            Section {
                ManageTagsRow(onShow: showTags)
                ThemeRow()
                PrivacyLockRows(availability: lockAvailability)
                SyncRows(iCloudAvailable: iCloudAvailable)
            } header: {
                Text("Other")
            } footer: {
                if !lockAvailability.canEnable {
                    Text("Set a device passcode in iOS Settings to use the lock.")
                }
            }
            AboutSection(onShowDeveloper: showDeveloper)
        }
        .navigationTitle("Settings")
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingDeveloper) {
            DeveloperCardView()
        }
        .sheet(isPresented: $isPresentingTags) {
            ManageTagsView()
        }
        .task {
            await refreshNotificationPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - Actions

    private func showDeveloper() {
        isPresentingDeveloper = true
    }

    private func showTags() {
        isPresentingTags = true
    }

    private func notificationsDidChange() {
        let actions = actions
        pendingReschedule?.cancel()
        pendingReschedule = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            actions.rescheduleAllNotifications()
        }
    }

    /// Returning from iOS Settings (permission, passcode, iCloud sign-in) is
    /// the moment any of the probes can have changed.
    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        lockAvailability = LockAuthenticator().availability()
        iCloudAvailable = ModelContainerCoordinator.isICloudAvailable
        Task {
            await refreshNotificationPermission()
        }
    }

    private func refreshNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(SampleData.previewContainer())
    .environment(ModelContainerCoordinator(syncEnabled: false, storeURL: nil))
}
