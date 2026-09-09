import Foundation

/// What the key-date editor sheet is presenting: a fresh date of a given
/// type, or an existing one.
enum KeyDateEditorItem: Identifiable {
    case new(KeyDateType)
    case edit(KeyDate)

    var id: String {
        switch self {
        case .new(let type): "new-\(type.rawValue)"
        case .edit(let keyDate): keyDate.id.uuidString
        }
    }

    var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}
