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
    @Environment(NotificationConsent.self) private var notificationConsent

    @State private var notificationsDenied = false
    @State private var lockAvailability = LockAuthenticator().availability()
    @State private var iCloudAvailable = ModelContainerCoordinator.isICloudAvailable

    /// The developer card. Presented from the `Form` rather than from inside
    /// `AboutSection`, because a `.sheet` on a `Section` is applied once per
    /// row and the competing presentations dismiss one another instantly.
    @State private var isPresentingDeveloper = false

    /// The tag vocabulary. Hoisted for the same reason as the card above.
    @State private var isPresentingTags = false
    @State private var isPresentingOnboarding = false

    /// Default-time changes settle into one reschedule pass (§9).
    /// The notifications switch instead awaits explicit authorization.
    /// Unstructured on purpose — it must survive switching tabs mid-settle.
    @State private var pendingReschedule: Task<Void, Never>?
    @State private var notificationError: String?

    private var actions: SettingsActions {
        SettingsActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        Form {
            NotificationDefaultsSection(
                notificationsDenied: notificationsDenied,
                isUpdatingNotifications: notificationConsent.isWorking,
                onChange: notificationsDidChange,
                onNotificationsChange: setNotificationsEnabled
            )
            .disabled(notificationConsent.isWorking)
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
            AboutSection(onShowOnboarding: showOnboarding, onShowDeveloper: showDeveloper)
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
        .sheet(isPresented: $isPresentingOnboarding) {
            OnboardingReplayView()
        }
        .task {
            await refreshNotificationPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .operationErrorAlert("Couldn't update notifications", message: $notificationError)
    }

    // MARK: - Actions

    private func showOnboarding() {
        isPresentingOnboarding = true
    }

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

    private func setNotificationsEnabled(_ enabled: Bool) {
        pendingReschedule?.cancel()
        if !enabled {
            notificationConsent.decline()
            return
        }
        Task {
            do {
                _ = try await notificationConsent.enable(in: modelContext)
                await refreshNotificationPermission()
            } catch {
                notificationError = error.localizedDescription
            }
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
    .environment(NotificationConsent())
}
