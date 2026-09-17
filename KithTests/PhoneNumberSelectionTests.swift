import Contacts
import Foundation
import Testing
@testable import Kith

/// The quick actions take one tap, so the choice of number is made for you.
/// These pin the ranking down.
struct PhoneNumberSelectionTests {
    private func labelled(_ label: String?, _ number: String) -> CNLabeledValue<CNPhoneNumber> {
        CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: number))
    }

    @Test func noNumbersMeansNoChoice() {
        #expect(PhoneNumberSelection.best(from: []) == nil)
    }

    @Test func iPhoneBeatsEverything() {
        let numbers = [
            labelled(CNLabelWork, "111"),
            labelled(CNLabelHome, "222"),
            labelled(CNLabelPhoneNumberMobile, "333"),
            labelled(CNLabelPhoneNumberiPhone, "444"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == "444")
    }

    @Test func mobileBeatsTheLandlines() {
        let numbers = [
            labelled(CNLabelHome, "222"),
            labelled(CNLabelWork, "111"),
            labelled(CNLabelPhoneNumberMobile, "333"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == "333")
    }

    @Test func mainBeatsHomeAndWork() {
        let numbers = [
            labelled(CNLabelWork, "111"),
            labelled(CNLabelPhoneNumberMain, "999"),
            labelled(CNLabelHome, "222"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == "999")
    }

    @Test func homeBeatsWork() {
        let numbers = [labelled(CNLabelWork, "111"), labelled(CNLabelHome, "222")]
        #expect(PhoneNumberSelection.best(from: numbers) == "222")
    }

    /// Nothing recognised falls to the card's own order, so an unlabelled
    /// number is still better than no number.
    @Test func anythingElseFallsBackToTheCardsOrder() {
        let numbers = [
            labelled(nil, "555"),
            labelled(CNLabelOther, "666"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == "555")
    }

    @Test func aRecognisedLabelStillWinsFromLastPlace() {
        let numbers = [labelled(nil, "555"), labelled(CNLabelPhoneNumberMobile, "333")]
        #expect(PhoneNumberSelection.best(from: numbers) == "333")
    }

    @Test func blankNumbersAreNotCandidates() {
        let numbers = [labelled(CNLabelPhoneNumberiPhone, "   "), labelled(CNLabelWork, "111")]
        #expect(PhoneNumberSelection.best(from: numbers) == "111")
    }

    /// A fax machine is never a person, so it never wins — even against an
    /// unlabelled number, which at least might be one.
    @Test func faxAndPagerAreNeverChosen() {
        let numbers = [
            labelled(CNLabelPhoneNumberHomeFax, "111"),
            labelled(CNLabelPhoneNumberPager, "222"),
            labelled(nil, "333"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == "333")
    }

    /// Nothing but a fax reads the same as nothing at all: the row hides
    /// rather than offering to ring a machine.
    @Test func aFaxOnlyCardHasNoNumber() {
        let numbers = [
            labelled(CNLabelPhoneNumberWorkFax, "111"),
            labelled(CNLabelPhoneNumberOtherFax, "222"),
        ]
        #expect(PhoneNumberSelection.best(from: numbers) == nil)
    }
}
