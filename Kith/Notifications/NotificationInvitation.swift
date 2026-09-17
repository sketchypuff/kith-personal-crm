import Foundation

struct NotificationInvitation: Identifiable {
    let personID: UUID
    var id: UUID { personID }
}
