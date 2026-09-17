import Foundation
import Testing
@testable import Kith

struct AddContactFlowStateTests {
    @Test func introductionDoesNotRequestAccessUntilAddIsChosen() async {
        let state = AddContactFlowState()
        var requests = 0
        await state.preparePicker {
            requests += 1
            return true
        }
        #expect(requests == 0)
        #expect(!state.isRequestingContactAccess)
        #expect(!state.isPickingContact)
    }

    @Test(arguments: [true, false])
    func pickerWaitsForTheContactsChoiceRegardlessOfItsAnswer(granted: Bool) async {
        let state = AddContactFlowState()
        state.begin()
        #expect(state.isRequestingContactAccess)
        #expect(!state.isPickingContact)

        var requests = 0
        await state.preparePicker {
            requests += 1
            await Task.yield()
            #expect(state.isRequestingContactAccess)
            #expect(!state.isPickingContact)
            return granted
        }

        #expect(requests == 1)
        #expect(!state.isRequestingContactAccess)
        #expect(state.isPickingContact)
        #expect(state.pickedContact == nil)
    }

    @Test func repeatedAddDoesNotBypassThePendingChoice() async {
        let state = AddContactFlowState()
        state.begin()
        await state.preparePicker {
            state.begin()
            #expect(state.isRequestingContactAccess)
            #expect(!state.isPickingContact)
            return true
        }
        #expect(state.isPickingContact)
    }

    @Test func anOpenPickerDoesNotRequestAccessAgain() async {
        let state = AddContactFlowState()
        var requests = 0
        state.begin()
        await state.preparePicker {
            requests += 1
            return true
        }
        state.begin()
        await state.preparePicker {
            requests += 1
            return true
        }
        #expect(requests == 1)
        #expect(state.isPickingContact)
        #expect(!state.isRequestingContactAccess)
    }

    @Test func addingAgainDoesNotReplaceAContactBeingSetUp() {
        let state = AddContactFlowState()
        state.pickedContact = PickedContact(id: "contact-id", name: "Maya")
        state.begin()
        #expect(state.pickedContact?.id == "contact-id")
        #expect(!state.isRequestingContactAccess)
    }

    @Test func pendingDismissalsAreNotResetByAnotherAdd() {
        let state = AddContactFlowState()
        state.pendingContact = PickedContact(id: "contact-id", name: "Maya")
        state.begin()
        #expect(state.pendingContact?.id == "contact-id")
        #expect(!state.isRequestingContactAccess)

        state.pendingContact = nil
        state.result = .created(Person(name: "Maya", linkedContactID: "contact-id"))
        state.begin()
        #expect(state.result != nil)
        #expect(!state.isRequestingContactAccess)
    }

    @Test func leavingDuringTheRequestDoesNotOpenThePicker() async {
        let state = AddContactFlowState()
        state.begin()
        await state.preparePicker {
            state.cancelContactAccessRequest()
            await Task.yield()
            return true
        }
        #expect(!state.isRequestingContactAccess)
        #expect(!state.isPickingContact)
    }

    @Test func cancellationBeforeStartingDoesNotAskForAccess() async {
        let state = AddContactFlowState()
        var requests = 0
        state.begin()
        let request = Task { @MainActor in
            await state.preparePicker {
                requests += 1
                return true
            }
        }
        request.cancel()
        state.cancelContactAccessRequest()
        await request.value
        #expect(requests == 0)
        #expect(!state.isRequestingContactAccess)
        #expect(!state.isPickingContact)
    }

    @Test func aCancelledAttemptCannotOverrideANewAttempt() async {
        let state = AddContactFlowState()
        state.begin()
        let request = Task { @MainActor in
            await state.preparePicker {
                withUnsafeCurrentTask { $0?.cancel() }
                state.cancelContactAccessRequest()
                state.begin()
                return true
            }
        }
        await request.value
        #expect(state.isRequestingContactAccess)
        #expect(!state.isPickingContact)

        await state.preparePicker { true }
        #expect(!state.isRequestingContactAccess)
        #expect(state.isPickingContact)
    }
}
