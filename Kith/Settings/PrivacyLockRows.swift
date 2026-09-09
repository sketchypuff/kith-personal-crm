import SwiftUI

/// The optional privacy gate's rows (Settings §6), placed in the Other
/// section. Turning the lock on authenticates once *before* the stored
/// switch commits; the require-unlock timing only appears once the lock is
/// on. The overlay and the foreground gate themselves are app-level
/// (`AppLockGate`) and read these values on each phase change.
struct PrivacyLockRows: View {
    let availability: LockAvailability

    @AppStorage(AppPreferences.Key.lockEnabled, store: AppPreferences.store)
    private var lockEnabled = false

    @AppStorage(AppPreferences.Key.lockGracePeriod, store: AppPreferences.store)
    private var gracePeriod: LockGracePeriod = .immediately

    /// The switch's on-screen position. It runs ahead of `lockEnabled` while
    /// the enabling authentication is in flight, and snaps back if that fails.
    @State private var lockRequested: Bool
    @State private var isAuthenticating = false

    private let authenticator = LockAuthenticator()

    init(availability: LockAvailability) {
        self.availability = availability
        _lockRequested = State(initialValue: AppPreferences.lockEnabled)
    }

    var body: some View {
        Group {
            Toggle(availability.toggleLabel, isOn: $lockRequested)
                .disabled(!availability.canEnable || isAuthenticating)

            if lockEnabled {
                Picker("Require unlock", selection: $gracePeriod) {
                    ForEach(LockGracePeriod.allCases, id: \.self) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onChange(of: lockRequested) { _, requested in
            lockRequestDidChange(requested)
        }
        .onChange(of: lockEnabled) { _, enabled in
            lockRequested = enabled
        }
    }

    // MARK: - Actions

    private func lockRequestDidChange(_ requested: Bool) {
        guard requested != lockEnabled else { return }
        if requested {
            Task {
                await enableLock()
            }
        } else {
            withAnimation {
                lockEnabled = false
            }
        }
    }

    /// Confirms the user can pass the gate they're setting (§6.1).
    private func enableLock() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: "Confirm you can unlock Kith before turning the lock on.") {
            withAnimation {
                lockEnabled = true
            }
        } else {
            lockRequested = false
        }
    }
}
