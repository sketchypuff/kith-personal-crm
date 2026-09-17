import Foundation

/// Two renderings of one contact number.
///
/// `tel:` and `sms:` are forgiving and take the number much as it was saved.
/// WhatsApp is not: it needs full international digits, and a great many
/// contacts are saved as bare local numbers. Everything needed to bridge that
/// gap lives here so the guesswork is in one testable place.
nonisolated enum PhoneNumberFormatter {
    /// E.164 allows fifteen digits; nothing shorter than six is a real number.
    private static let validLength = 6...15

    /// What `tel:` and `sms:` are handed: the leading `+` if the card had one,
    /// then digits and the DTMF characters, and nothing else that would need
    /// escaping in a URL.
    static func dialForm(_ raw: String) -> String? {
        let allowed = Set("0123456789*#")
        let body = String(raw.filter { allowed.contains($0) })
        guard !body.isEmpty else { return nil }
        return raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" + body : body
    }

    /// What WhatsApp is handed: international digits with no `+` and no
    /// punctuation. Returns nil rather than guessing when the number can't be
    /// resolved to something international — a wrong number opens a stranger's
    /// chat, so the button hides instead.
    static func e164Digits(_ raw: String, region: String?) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        // Already international, either notation.
        if trimmed.hasPrefix("+") {
            return validated(String(digits))
        }
        if digits.hasPrefix("00") {
            return validated(String(digits.dropFirst(2)))
        }

        // A local number: it only becomes dialable once we know where it's from.
        guard let region, let code = DiallingCodes.code(for: region) else { return nil }
        var national = String(digits)
        if national.hasPrefix("0") && !DiallingCodes.keepsTrunkZero(region) {
            national.removeFirst()
        }
        guard !national.isEmpty else { return nil }
        return validated(code + national)
    }

    private static func validated(_ digits: String) -> String? {
        validLength.contains(digits.count) ? digits : nil
    }
}
