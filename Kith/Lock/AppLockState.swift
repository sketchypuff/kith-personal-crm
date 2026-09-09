import Foundation
import SwiftUI

/// The privacy lock's state machine (Settings §6, PRD P0-13), driven by
/// `scenePhase`. Preferences are read through closures at each transition —
/// never `@AppStorage`, which must not live in an `@Observable` class.
///
/// - `isLocked`: the foreground gate is up; nothing renders behind it.
/// - `isCovered`: the app-switcher privacy overlay is showing.
@Observable
final class AppLockState {
    private(set) var isLocked: Bool
    private(set) var isCovered = false

    /// When the app last resigned active while unlocked, and whether the lock
    /// was on at that moment. Snapshotting the switch at resign time means
    /// enabling the lock *during* its own Face ID prompt (which makes the
    /// scene inactive) doesn't lock the user out the instant they return.
    private var resignedActiveAt: Date?
    private var wasArmedAtResign = false

    private let now: () -> Date
    private let lockEnabled: () -> Bool
    private let gracePeriod: () -> LockGracePeriod

    init(
        now: @escaping () -> Date = { .now },
        lockEnabled: @escaping () -> Bool = { AppPreferences.lockEnabled },
        gracePeriod: @escaping () -> LockGracePeriod = { AppPreferences.lockGracePeriod }
    ) {
        self.now = now
        self.lockEnabled = lockEnabled
        self.gracePeriod = gracePeriod
        // A cold launch with the lock on starts gated.
        isLocked = lockEnabled()
    }

    func scenePhaseDidChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            didBecomeActive()
        case .inactive, .background:
            didResignActive()
        @unknown default:
            break
        }
    }

    /// Called by the lock screen after `LAContext` succeeds.
    func unlock() {
        isLocked = false
    }

    // MARK: - Transitions

    private func didResignActive() {
        let armed = lockEnabled()
        isCovered = armed
        // Only an *unlocked* app has anything to gate; the first resign of a
        // stretch away is the one the grace period measures from.
        guard resignedActiveAt == nil, !isLocked else { return }
        resignedActiveAt = now()
        wasArmedAtResign = armed
    }

    private func didBecomeActive() {
        isCovered = false
        defer {
            resignedActiveAt = nil
            wasArmedAtResign = false
        }
        guard wasArmedAtResign, lockEnabled(), let resignedActiveAt else { return }
        if now().timeIntervalSince(resignedActiveAt) >= gracePeriod().duration {
            isLocked = true
        }
    }
}
