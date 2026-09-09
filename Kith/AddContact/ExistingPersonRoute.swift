import Foundation

/// Navigation value for the duplicate-guard push: the existing person's
/// detail, shown with the transient "Already in Kith" note (Add Contact §3).
struct ExistingPersonRoute: Hashable {
    let person: Person
}
