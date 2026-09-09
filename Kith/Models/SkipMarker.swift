import Foundation
import SwiftData

/// A visible "skipped" marker in the timeline. Deliberately not a `Touch`
/// so a skip can never be counted as a real reach-out.
@Model
final class SkipMarker {
    var id: UUID = UUID()
    var date: Date = Date.now

    var person: Person?   // inverse declared on Person.skipMarkers

    init(date: Date = .now) {
        self.date = date
    }
}
