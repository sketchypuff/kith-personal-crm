import Contacts
import Foundation

/// Picks the one number to reach a person on.
///
/// A contact card routinely carries four numbers and the quick actions take
/// one tap, so the choice is made here rather than handed to the user. Kept
/// apart from `ContactPhoneCache` so the ranking is testable without a
/// `CNContactStore`.
nonisolated enum PhoneNumberSelection {
    /// Most-likely-to-reach-a-person first. Anything unlabelled or labelled
    /// something else falls to the end in the order the card lists it.
    private static let priority: [String] = [
        CNLabelPhoneNumberiPhone,
        CNLabelPhoneNumberMobile,
        CNLabelPhoneNumberMain,
        CNLabelHome,
        CNLabelWork,
    ]

    /// Never a person on the other end, so never worth offering. A card with
    /// nothing but these has nothing to reach them on, and the row hides —
    /// the same answer as a card with no numbers at all.
    private static let unreachable: Set<String> = [
        CNLabelPhoneNumberHomeFax,
        CNLabelPhoneNumberWorkFax,
        CNLabelPhoneNumberOtherFax,
        CNLabelPhoneNumberPager,
    ]

    /// The best number on the card, or nil when there is nothing dialable.
    static func best(from numbers: [CNLabeledValue<CNPhoneNumber>]) -> String? {
        let candidates = numbers.filter {
            !$0.value.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
                && !unreachable.contains($0.label ?? "")
        }
        guard !candidates.isEmpty else { return nil }

        // Stable: equal-ranked numbers keep the card's own order.
        let best = candidates.enumerated().min { lhs, rhs in
            let left = rank(of: lhs.element)
            let right = rank(of: rhs.element)
            return left == right ? lhs.offset < rhs.offset : left < right
        }
        return best?.element.value.stringValue
    }

    private static func rank(of number: CNLabeledValue<CNPhoneNumber>) -> Int {
        guard let label = number.label,
              let index = priority.firstIndex(of: label)
        else { return priority.count }
        return index
    }
}
