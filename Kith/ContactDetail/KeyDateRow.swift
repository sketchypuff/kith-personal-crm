import SwiftUI

/// A key-date row: label, the date with its lead time, and how far off the
/// next occurrence is.
struct KeyDateRow: View {
    let keyDate: KeyDate
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(keyDate.label)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let occurrence = keyDate.nextOccurrence(from: now) {
                Text(relativeLabel(for: occurrence))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edits this date")
    }

    /// "12 Apr 1990 · 3 days before", with the year only when known.
    private var detail: String {
        var parts: [String] = []
        if let date = keyDate.displayDate(in: now) {
            let style: Date.FormatStyle = keyDate.year == nil
                ? .dateTime.day().month(.abbreviated)
                : .dateTime.day().month(.abbreviated).year()
            parts.append(date.formatted(style))
        }
        if !keyDate.reminderEnabled {
            parts.append("Reminder off")
        } else if keyDate.leadTimeDays == 0 {
            parts.append("On the day")
        } else if keyDate.leadTimeDays == 1 {
            parts.append("1 day before")
        } else {
            parts.append("\(keyDate.leadTimeDays) days before")
        }
        return parts.joined(separator: " · ")
    }

    private func relativeLabel(for occurrence: Date) -> String {
        switch KeyDateEngine.daysUntil(occurrence, from: now) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: occurrence.formatted(.relative(presentation: .named))
        }
    }
}
