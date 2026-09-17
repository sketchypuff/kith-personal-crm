import Testing
@testable import Kith

struct PermissionRequestQueueTests {
    @Test func systemPermissionRequestsDoNotOverlap() async throws {
        var active = 0
        var peak = 0
        let first = Task { @MainActor in
            try await PermissionRequestQueue.perform {
                active += 1
                peak = max(peak, active)
                await Task.yield()
                active -= 1
                return true
            }
        }
        let second = Task { @MainActor in
            try await PermissionRequestQueue.perform {
                active += 1
                peak = max(peak, active)
                await Task.yield()
                active -= 1
                return true
            }
        }
        #expect(try await first.value)
        #expect(try await second.value)
        #expect(peak == 1)
        #expect(active == 0)
    }
}
