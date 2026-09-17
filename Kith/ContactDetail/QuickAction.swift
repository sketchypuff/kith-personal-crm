import Foundation
import UIKit

/// The three ways out of Kith and into a conversation.
///
/// Each case owns its wording, its glyph, the URL that opens the other app,
/// and how the resulting catch-up reads in the timeline — so adding a fourth
/// is one case, not a sweep through the view.
nonisolated enum QuickAction: String, CaseIterable, Identifiable {
    case call
    case message
    case whatsapp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .call: "Call"
        // Not "iMessage": iOS decides blue or green on its own, and a button
        // that promises one and delivers the other is a button that lies.
        case .message: "Message"
        case .whatsapp: "WhatsApp"
        }
    }

    /// Two glyph sources, because WhatsApp has no system symbol: the asset in
    /// `WhatsAppGlyph.imageset` is Bootstrap Icons' `bi-whatsapp`, MIT
    /// licensed and therefore redistributable, drawn as a template so it takes
    /// the same tint as the other two rather than WhatsApp green. Meta's own
    /// brand pack is deliberately not used — it's a trademark behind licence
    /// terms, and an MIT glyph of the same mark avoids the question entirely.
    ///
    /// The fallback still stands in if the asset ever goes missing, so the
    /// button works either way and the mark is never approximated by hand.
    ///
    /// The fallback is `phone.bubble.fill` — a handset inside a speech bubble,
    /// which is what WhatsApp *is* without borrowing anything that belongs to
    /// them. It also has to sit beside Message's plain bubble without the two
    /// reading as the same icon twice, which rules out the bubble pair.
    enum Icon {
        case system(String)
        case asset(name: String, fallback: String)
    }

    var icon: Icon {
        switch self {
        case .call: .system("phone.fill")
        case .message: .system("message.fill")
        case .whatsapp: .asset(name: "WhatsAppGlyph", fallback: "phone.bubble.fill")
        }
    }

    /// What the timeline records, so the history says how you got in touch.
    var touchKind: TouchKind {
        switch self {
        case .call: .called
        case .message: .messaged
        case .whatsapp: .whatsapp
        }
    }

    /// Nil when this action can't reach that number — an unresolvable local
    /// number hides WhatsApp rather than opening a stranger's chat.
    func url(number: String, region: String?) -> URL? {
        switch self {
        case .call:
            guard let dial = PhoneNumberFormatter.dialForm(number) else { return nil }
            return URL(string: "tel:\(dial)")
        case .message:
            guard let dial = PhoneNumberFormatter.dialForm(number) else { return nil }
            return URL(string: "sms:\(dial)")
        case .whatsapp:
            guard let digits = PhoneNumberFormatter.e164Digits(number, region: region) else { return nil }
            return URL(string: "whatsapp://send?phone=\(digits)")
        }
    }

    /// WhatsApp is the one case that can be missing from the phone. The check
    /// needs `whatsapp` listed under `LSApplicationQueriesSchemes` in
    /// `Kith-Info.plist` — without it this silently answers false and the
    /// button simply never appears.
    @MainActor
    var isAvailable: Bool {
        guard self == .whatsapp else { return true }
        guard let probe = URL(string: "whatsapp://app") else { return false }
        return UIApplication.shared.canOpenURL(probe)
    }
}
