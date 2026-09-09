import Foundation

nonisolated enum KeyDateType: String, Codable, CaseIterable {
    case birthday, anniversary, custom

    var label: String {
        switch self {
        case .birthday: "Birthday"
        case .anniversary: "Anniversary"
        case .custom: "Custom"
        }
    }
}
