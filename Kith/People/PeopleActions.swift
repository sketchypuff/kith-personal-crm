import Foundation
import SwiftData

/// The roster's one mutation: the confirmed, cascading hard delete (People §9).
struct PeopleActions {
    let context: ModelContext
    var notifications = NotificationScheduler()

    /// Order matters: read the identifiers before the cascade makes `keyDates` unreadable.
    func delete(_ person: Person) {
        let ids = person.pendingNotificationIDs
        notifications.cancel(ids: ids)
        context.delete(person)
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("People save failed: \(error)")
        }
    }
}
