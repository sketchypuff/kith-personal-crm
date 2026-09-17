import SwiftData
import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(NotificationConsent.self) private var consent
    @State private var status: UNAuthorizationStatus?
    @State private var returningFromSettings = false
    @State private var errorMessage: String?

    var body: some View {
        OnboardingMessageView(
            illustration: OnboardingPage.rhythm.illustration,
            title: "A gentle heads-up.",
            message: "Let Kith remind you when it's time to reach out or an important date is coming up.",
            detail: status == .denied
                ? "Notifications are off in iOS Settings. You can turn them on there, or keep using Kith without them."
                : "Your reminders still appear in Upcoming if you choose not to receive notifications. You can turn them on later in Settings."
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                if status == nil || consent.isWorking {
                    ProgressView()
                        .accessibilityLabel("Updating notification settings")
                }
                Button(action: enable) {
                    Text(status == .denied ? "Open iOS Settings" : "Enable notifications")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(status == nil || consent.isWorking)
                .accessibilityIdentifier("onboarding.enableNotifications")

                Button(action: skip) {
                    Text("Not now")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                    .disabled(consent.isWorking)
                    .accessibilityIdentifier("onboarding.skipNotifications")
            }
            .font(.headline)
            .padding()
            .background(.background)
        }
        .toolbarTitleDisplayMode(.inline)
        .operationErrorAlert("Couldn't enable notifications", message: $errorMessage)
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshStatus() }
            }
        }
    }

    private func refreshStatus() async {
        status = await consent.notifications.client.authorizationStatus()
        if returningFromSettings, status != .denied, status != .notDetermined, !consent.isWorking {
            returningFromSettings = false
            await requestAndSchedule()
        }
    }

    private func enable() {
        if status == .denied {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                errorMessage = "iOS Settings couldn't be opened."
                return
            }
            returningFromSettings = true
            openURL(url) { opened in
                if !opened {
                    returningFromSettings = false
                    errorMessage = "iOS Settings couldn't be opened."
                }
            }
        } else {
            Task { await requestAndSchedule() }
        }
    }

    private func requestAndSchedule() async {
        do {
            _ = try await consent.enable(in: modelContext)
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func skip() {
        consent.decline()
        onFinished()
    }
}
