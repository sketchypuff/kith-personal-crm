import Foundation
import SwiftData

/// One name in the tag vocabulary — what a person *can* be tagged with.
///
/// Deliberately not related to `Person`. People keep their `tags: [String]` and
/// are matched by folded name, the way every tag comparison in the app already
/// works, so existing data stays valid with no migration. The cost is that the
/// two can drift; `TagActions.delete` is what keeps them in step.
///
/// Shaped for CloudKit mirroring like the rest: no unique constraint (the
/// duplicate guard is a fetch), every attribute defaulted.
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    init(name: String = "") {
        self.name = name
    }
}
