import Foundation

/// Where someone is, and therefore what time it is for them.
///
/// Kith never asks for this. It reads the country calling code off the number
/// already on their contact card — the same number the Call button uses, read
/// live and never stored — and turns that into a timezone. The user only steps
/// in when the guess was absent or wrong, and that correction is the one thing
/// here that is written down (`Person.timeZoneIdentifier`).
///
/// Pure and `nonisolated` so the rules can be tested without a container.
nonisolated enum PersonTimeZone {
    /// A zone and how it was arrived at. `isGuess` is false only when the user
    /// chose it themselves.
    struct Resolved: Equatable {
        let timeZone: TimeZone
        let isGuess: Bool
    }

    /// E.164 allows fifteen digits; nothing shorter than six is a real number.
    /// The same bounds `PhoneNumberFormatter` holds to.
    private static let validLength = 6...15

    /// The zone to show for a person, or nil to show nothing.
    ///
    /// A choice the user made is always returned — they asked the question, so
    /// they get an answer even when it agrees with their own clock. **A guess
    /// that agrees with the device is dropped**, because "9:04 PM, same as
    /// you" is a line that costs a reader attention and tells them nothing.
    static func resolve(
        identifier: String?,
        number: String?,
        device: TimeZone = .current,
        now: Date = .now
    ) -> Resolved? {
        if let identifier, let chosen = TimeZone(identifier: identifier) {
            return Resolved(timeZone: chosen, isGuess: false)
        }
        guard let guessed = guess(number: number) else { return nil }
        guard guessed.secondsFromGMT(for: now) != device.secondsFromGMT(for: now) else { return nil }
        return Resolved(timeZone: guessed, isGuess: true)
    }

    /// The zone a number implies, with no override in play.
    ///
    /// Only an international number carries the answer. A number saved in local
    /// form says nothing about where its owner is — it is, by definition,
    /// dialled from wherever this phone already is — so it resolves to nothing
    /// rather than to the user's own zone.
    static func guess(number: String?) -> TimeZone? {
        guard let number else { return nil }
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        let digits = String(trimmed.filter(\.isNumber))

        let international: String
        if trimmed.hasPrefix("+") {
            international = digits
        } else if digits.hasPrefix("00") {
            international = String(digits.dropFirst(2))
        } else {
            return nil
        }

        guard validLength.contains(international.count) else { return nil }
        guard let region = DiallingCodes.region(forInternationalDigits: international) else { return nil }
        return RegionTimeZones.timeZone(for: region)
    }

    // MARK: - Wording

    /// How far ahead or behind the reader they are: `3h ahead`, `5h 30m
    /// behind`, `45m ahead`, or `same time as you`. Abbreviated the way
    /// `3d overdue` is, and never a complaint about the hour.
    static func offsetLabel(for timeZone: TimeZone, device: TimeZone = .current, now: Date = .now) -> String {
        let delta = timeZone.secondsFromGMT(for: now) - device.secondsFromGMT(for: now)
        guard delta != 0 else { return "same time as you" }

        let direction = delta > 0 ? "ahead" : "behind"
        let (hours, minutes) = components(of: delta)

        switch (hours, minutes) {
        case (0, let m): return "\(m)m \(direction)"
        case (let h, 0): return "\(h)h \(direction)"
        case (let h, let m): return "\(h)h \(m)m \(direction)"
        }
    }

    /// The same fact spelled out, because VoiceOver reads `3h` as "three h".
    static func offsetAccessibilityLabel(
        for timeZone: TimeZone,
        device: TimeZone = .current,
        now: Date = .now
    ) -> String {
        let delta = timeZone.secondsFromGMT(for: now) - device.secondsFromGMT(for: now)
        guard delta != 0 else { return "the same time as you" }

        let direction = delta > 0 ? "ahead" : "behind"
        let (hours, minutes) = components(of: delta)
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return parts.joined(separator: " ") + " " + direction
    }

    /// The clock face in their zone: `9:04 PM`, in whatever form the reader's
    /// own locale writes one.
    static func timeLabel(for timeZone: TimeZone, now: Date = .now) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return now.formatted(style)
    }

    private static func components(of delta: Int) -> (hours: Int, minutes: Int) {
        let total = abs(delta) / 60
        return (total / 60, total % 60)
    }
}
