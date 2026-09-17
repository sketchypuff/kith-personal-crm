import UserNotifications

struct NotificationClient {
    var authorizationStatus: () async -> UNAuthorizationStatus
    var requestAuthorization: () async throws -> Bool
    var add: (UNNotificationRequest) async throws -> Void
    var remove: ([String]) -> Void
    var removeAll: () -> Void

    static var live: NotificationClient {
        let center = UNUserNotificationCenter.current()
        return NotificationClient(
            authorizationStatus: { await center.notificationSettings().authorizationStatus },
            requestAuthorization: {
                try await PermissionRequestQueue.perform {
                    try await center.requestAuthorization(options: [.alert, .sound, .badge])
                }
            },
            add: { try await center.add($0) },
            remove: { center.removePendingNotificationRequests(withIdentifiers: $0) },
            removeAll: { center.removeAllPendingNotificationRequests() }
        )
    }

    func authorizeIfNeeded() async throws -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined: try await requestAuthorization()
        case .denied: false
        @unknown default: false
        }
    }
}
