import Foundation
import Observation

/// Coordinates Contacts consent, the picker, and the Setup sheet.
@Observable
final class AddContactFlowState {
    private(set) var isRequestingContactAccess = false
    var isPickingContact = false
    var pickedContact: PickedContact?
    var pendingContact: PickedContact?
    var result: AddContactResult?

    func begin() {
        guard !isRequestingContactAccess, !isPickingContact,
              pickedContact == nil, pendingContact == nil, result == nil
        else { return }
        isRequestingContactAccess = true
    }

    func preparePicker(
        requestContactAccess: @MainActor () async -> Bool = { await ContactAccess.ensureGranted() }
    ) async {
        guard isRequestingContactAccess, !Task.isCancelled else { return }
        _ = await requestContactAccess()
        guard isRequestingContactAccess, !Task.isCancelled else { return }

        isRequestingContactAccess = false
        // The system picker can still share one contact if ongoing access was declined.
        isPickingContact = true
    }

    func cancelContactAccessRequest() {
        isRequestingContactAccess = false
    }
}
