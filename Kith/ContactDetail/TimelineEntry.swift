import Foundation

/// One row of the contact sheet's timeline: a touch or a skip marker, merged
/// and sorted newest first. A skip is carried as its own kind so it can be
/// drawn distinctly and is never counted as a touch (PRD P0-8).
struct TimelineEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case touch(note: String?)
        case skipped
    }

    let id: UUID
    let date: Date
    let kind: Kind

    var isTouch: Bool {
        if case .touch = kind { return true }
        return false
    }

    static func build(for person: Person) -> [TimelineEntry] {
        let touches = (person.touches ?? []).map { touch in
            let note = touch.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return TimelineEntry(id: touch.id, date: touch.date, kind: .touch(note: note.isEmpty ? nil : note))
        }
        let skips = (person.skipMarkers ?? []).map { marker in
            TimelineEntry(id: marker.id, date: marker.date, kind: .skipped)
        }
        return (touches + skips).sorted { $0.date > $1.date }
    }
}
