import SwiftUI

/// The app-level gate around the tab shell. While locked, the tab tree is not
/// in the hierarchy at all — there is no data access, not even read, behind an
/// unpassed gate (Settings §6.4). While inactive or backgrounded with the lock
/// on, the privacy overlay covers whatever is showing (§6.3).
struct AppLockGate: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLockState()

    var body: some View {
        Group {
            if lock.isLocked {
                LockScreenView(onUnlock: unlock)
            } else {
                RootTabView()
            }
        }
        .overlay {
            if lock.isCovered {
                PrivacyOverlayView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            lock.scenePhaseDidChange(phase)
        }
    }

    private func unlock() {
        withAnimation {
            lock.unlock()
        }
    }
}
