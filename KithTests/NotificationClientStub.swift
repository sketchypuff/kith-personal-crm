import Foundation
import UserNotifications
@testable import Kith

final class NotificationClientStub {
    var status: UNAuthorizationStatus = .notDetermined
    var grantsPermission = true
    var authorizationError: Error?
    var failAfterAdds: Int?
    var authorizationRequests = 0
    var added: [UNNotificationRequest] = []
    var removed: [String] = []
    var removeAllCount = 0

    var client: NotificationClient {
        NotificationClient(
            authorizationStatus: { self.status },
            requestAuthorization: {
                self.authorizationRequests += 1
                if let error = self.authorizationError { throw error }
                self.status = self.grantsPermission ? .authorized : .denied
                return self.grantsPermission
            },
            add: { request in
                if let limit = self.failAfterAdds, self.added.count >= limit {
                    throw CocoaError(.fileWriteOutOfSpace)
                }
                self.added.append(request)
            },
            remove: { self.removed.append(contentsOf: $0) },
            removeAll: { self.removeAllCount += 1 }
        )
    }
}
