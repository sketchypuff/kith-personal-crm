import Foundation
import SwiftUI
import Testing
@testable import Kith

struct AppLockStateTests {
    /// A settable clock and preferences the state reads through closures.
    final class Harness {
        var now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var lockEnabled = true
        var gracePeriod: LockGracePeriod = .immediately

        lazy var state = AppLockState(
            now: { [unowned self] in self.now },
            lockEnabled: { [unowned self] in self.lockEnabled },
            gracePeriod: { [unowned self] in self.gracePeriod }
        )

        func advance(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    private func unlockedHarness(grace: LockGracePeriod = .immediately) -> Harness {
        let harness = Harness()
        harness.gracePeriod = grace
        harness.state.unlock()
        return harness
    }

    @Test func coldLaunchStartsGatedOnlyWhenTheLockIsOn() {
        let on = Harness()
        #expect(on.state.isLocked)

        let off = Harness()
        off.lockEnabled = false
        #expect(!off.state.isLocked)
    }

    @Test func immediatelyLocksOnEveryReturn() {
        let h = unlockedHarness()
        h.state.scenePhaseDidChange(.background)
        h.state.scenePhaseDidChange(.active)
        #expect(h.state.isLocked)
    }

    @Test func gracePeriodAllowsABriefGlanceAway() {
        let h = unlockedHarness(grace: .afterOneMinute)
        h.state.scenePhaseDidChange(.inactive)
        h.state.scenePhaseDidChange(.background)
        h.advance(30)
        h.state.scenePhaseDidChange(.active)
        #expect(!h.state.isLocked)

        h.state.scenePhaseDidChange(.background)
        h.advance(90)
        h.state.scenePhaseDidChange(.active)
        #expect(h.state.isLocked)
    }

    @Test func graceIsMeasuredFromTheFirstResignNotTheLast() {
        let h = unlockedHarness(grace: .afterOneMinute)
        h.state.scenePhaseDidChange(.inactive)
        h.advance(45)
        h.state.scenePhaseDidChange(.background)   // must not restart the clock
        h.advance(45)
        h.state.scenePhaseDidChange(.active)
        #expect(h.state.isLocked)
    }

    @Test func overlayCoversOnlyWhileAwayWithTheLockOn() {
        let h = unlockedHarness(grace: .afterFiveMinutes)
        #expect(!h.state.isCovered)
        h.state.scenePhaseDidChange(.inactive)
        #expect(h.state.isCovered)
        h.state.scenePhaseDidChange(.active)
        #expect(!h.state.isCovered)

        h.lockEnabled = false
        h.state.scenePhaseDidChange(.background)
        #expect(!h.state.isCovered)
    }

    @Test func lockOffMeansNoGateAtAll() {
        let h = Harness()
        h.lockEnabled = false
        h.state.scenePhaseDidChange(.background)
        h.advance(3_600)
        h.state.scenePhaseDidChange(.active)
        #expect(!h.state.isLocked)
    }

    @Test func enablingDuringItsOwnPromptDoesNotLockOnReturn() {
        let h = Harness()
        h.lockEnabled = false
        // The Face ID prompt for "turn the lock on" makes the scene inactive…
        h.state.scenePhaseDidChange(.inactive)
        // …the user passes, Settings commits the switch…
        h.lockEnabled = true
        // …and the scene comes back. Nothing to gate yet: the lock wasn't armed at resign.
        h.state.scenePhaseDidChange(.active)
        #expect(!h.state.isLocked)

        // The next stretch away is gated.
        h.state.scenePhaseDidChange(.background)
        h.state.scenePhaseDidChange(.active)
        #expect(h.state.isLocked)
    }

    @Test func unlockingSurvivesTheAuthenticationPromptsOwnPhaseChanges() {
        let h = Harness()
        #expect(h.state.isLocked)
        h.state.scenePhaseDidChange(.inactive)   // the system prompt
        h.state.unlock()
        h.state.scenePhaseDidChange(.active)
        #expect(!h.state.isLocked)
    }
}
