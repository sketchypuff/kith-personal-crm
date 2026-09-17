import Foundation

/// How a catch-up happened. `reachedOut` is what Upcoming's check and the
/// widget's intent record; the three named cases come from Contact Detail's
/// quick actions, so the timeline can say how you got in touch.
///
/// CloudKit-safe: these ride the existing `kindRaw` string, and `Touch.kind`
/// already falls back to `.reachedOut`, so a build that predates a case reads
/// it as a plain catch-up rather than breaking.
nonisolated enum TouchKind: String, Codable {
    case reachedOut
    case called
    case messaged
    case whatsapp

    /// How the timeline titles it.
    var timelineTitle: String {
        switch self {
        case .reachedOut: "Reached out"
        case .called: "Called"
        case .messaged: "Messaged"
        case .whatsapp: "WhatsApp"
        }
    }
}
