import Foundation
import SwiftData

/// A logged interaction. Created only from Today's check or the widget's intent.
@Model
final class Touch {
    var id: UUID = UUID()
    var date: Date = Date.now
    var note: String? = nil
    var kindRaw: String = TouchKind.reachedOut.rawValue

    var person: Person?   // inverse declared on Person.touches

    init(date: Date = .now, note: String? = nil) {
        self.date = date
        self.note = note
    }

    var kind: TouchKind {
        get { TouchKind(rawValue: kindRaw) ?? .reachedOut }
        set { kindRaw = newValue.rawValue }
    }
}
