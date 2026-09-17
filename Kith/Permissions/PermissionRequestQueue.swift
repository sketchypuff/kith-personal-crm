import Foundation

enum PermissionRequestQueue {
    private static var tail: Task<Void, Never>?

    static func perform(_ operation: @escaping @MainActor () async throws -> Bool) async throws -> Bool {
        let previous = tail
        let request = Task {
            await previous?.value
            return try await operation()
        }
        // The tail only tracks completion; the caller still receives any error.
        tail = Task { _ = await request.result }
        return try await request.value
    }
}
