import Foundation
import Testing
@testable import Kith

/// WhatsApp will not open a chat without full international digits, and most
/// contacts are saved as bare local numbers. This is where that gap is bridged,
/// and where a wrong guess would open a stranger's conversation.
struct PhoneNumberFormatterTests {

    // MARK: - Dial form

    @Test func dialFormKeepsThePlusAndDropsThePunctuation() {
        #expect(PhoneNumberFormatter.dialForm("+91 (98765) 43-210") == "+919876543210")
    }

    @Test func dialFormKeepsALocalNumberLocal() {
        #expect(PhoneNumberFormatter.dialForm("098765 43210") == "09876543210")
    }

    @Test func dialFormKeepsExtensionCharacters() {
        #expect(PhoneNumberFormatter.dialForm("+1 800 555 0100,,#42") == "+18005550100#42")
    }

    @Test func dialFormRefusesSomethingWithNoDigits() {
        #expect(PhoneNumberFormatter.dialForm("") == nil)
        #expect(PhoneNumberFormatter.dialForm("call me") == nil)
    }

    // MARK: - E.164

    @Test func anInternationalNumberIsUsedAsGiven() {
        #expect(PhoneNumberFormatter.e164Digits("+91 98765 43210", region: "US") == "919876543210")
    }

    @Test func theOtherInternationalNotationIsUnderstoodToo() {
        #expect(PhoneNumberFormatter.e164Digits("0091 98765 43210", region: "US") == "919876543210")
    }

    @Test func aLocalNumberTakesTheDevicesOwnCountry() {
        #expect(PhoneNumberFormatter.e164Digits("98765 43210", region: "IN") == "919876543210")
        #expect(PhoneNumberFormatter.e164Digits("(415) 555-0100", region: "US") == "14155550100")
    }

    @Test func theTrunkZeroIsDroppedBeforeTheCountryCode() {
        #expect(PhoneNumberFormatter.e164Digits("07700 900123", region: "GB") == "447700900123")
    }

    /// Italy is the well-known exception: its leading zero is part of the
    /// number, not a trunk prefix.
    @Test func italyKeepsItsLeadingZero() {
        #expect(PhoneNumberFormatter.e164Digits("06 6982 1234", region: "IT") == "390669821234")
    }

    /// Better a missing button than a stranger's chat.
    @Test func anUnresolvableLocalNumberProducesNothing() {
        #expect(PhoneNumberFormatter.e164Digits("98765 43210", region: nil) == nil)
        #expect(PhoneNumberFormatter.e164Digits("98765 43210", region: "ZZ") == nil)
    }

    @Test func nonsenseLengthsAreRejected() {
        #expect(PhoneNumberFormatter.e164Digits("+1 234", region: "US") == nil)
        #expect(PhoneNumberFormatter.e164Digits("+1234567890123456789", region: "US") == nil)
        #expect(PhoneNumberFormatter.e164Digits("", region: "IN") == nil)
    }

    @Test func aRegionIsMatchedCaseInsensitively() {
        #expect(PhoneNumberFormatter.e164Digits("98765 43210", region: "in") == "919876543210")
    }

    // MARK: - The URLs the buttons actually open

    @MainActor
    @Test func eachActionBuildsItsOwnUrl() {
        let number = "+91 98765 43210"
        #expect(QuickAction.call.url(number: number, region: "IN")?.absoluteString == "tel:+919876543210")
        #expect(QuickAction.message.url(number: number, region: "IN")?.absoluteString == "sms:+919876543210")
        #expect(
            QuickAction.whatsapp.url(number: number, region: "IN")?.absoluteString
                == "whatsapp://send?phone=919876543210"
        )
    }

    /// Call and Message still work on a number WhatsApp can't resolve — the
    /// reason availability is decided per action rather than for the row.
    @MainActor
    @Test func onlyWhatsAppNeedsTheCountryCode() {
        let number = "98765 43210"
        #expect(QuickAction.call.url(number: number, region: nil) != nil)
        #expect(QuickAction.message.url(number: number, region: nil) != nil)
        #expect(QuickAction.whatsapp.url(number: number, region: nil) == nil)
    }
}
