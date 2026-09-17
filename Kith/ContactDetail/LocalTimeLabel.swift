import SwiftUI

/// What time it is where they are: a globe-and-clock mark, then
/// `9:04 PM · 3h ahead`.
///
/// Wrapped in a `TimelineView(.everyMinute)` because a clock that has read
/// 9:04 PM for twenty minutes is a wrong clock, and this screen otherwise only
/// refreshes its sense of now when the app comes back to the foreground. The
/// wording is derived in `PersonTimeZone` so it can be tested without a view.
///
/// Set in `.subheadline` to match the catch-up line directly above it: the two
/// read as one block answering "how are we doing, and is now a sane hour", so
/// stepping the second one down in size would rank it below a status it is
/// meant to sit beside.
///
/// Laid out as a plain `HStack` rather than a `Label`. The header is a row
/// inside a `List`, and `Label` there reserves an icon column wide enough to
/// align icons down a settings screen — right for rows, far too much air for
/// one centred phrase. `.labelStyle(.titleAndIcon)` does not undo it either;
/// the column survives the style. An `HStack` is simply immune, and 6pt is
/// what a `Label` gives when nothing reserves a column for it. The mark is
/// decorative and hidden from VoiceOver; the text carries the line in words.
struct LocalTimeLabel: View {
    let timeZone: TimeZone

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            HStack(spacing: 6) {
                Image(systemName: "globe.badge.clock")
                    .accessibilityHidden(true)
                Text("\(PersonTimeZone.timeLabel(for: timeZone, now: now)) · \(PersonTimeZone.offsetLabel(for: timeZone, now: now))")
                    .accessibilityLabel(
                        "\(PersonTimeZone.timeLabel(for: timeZone, now: now)), \(PersonTimeZone.offsetAccessibilityLabel(for: timeZone, now: now))"
                    )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
