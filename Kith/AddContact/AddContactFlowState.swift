import Foundation

/// View state for the picker → duplicate guard → Setup sheet flow.
struct AddContactFlowState {
    var isPickingContact = false
    var pickedContact: PickedContact?

    mutating func begin() {
        isPickingContact = true
    }
}
