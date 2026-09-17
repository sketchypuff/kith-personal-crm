import SwiftUI

/// One timeline entry. A touch gets the check glyph and its note; a skip
/// gets a visibly different glyph and never reads as a touch.
struct TimelineRow: View {
    let entry: TimelineEntry

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                Text("\(entry.date, format: .dateTime.day().month(.abbreviated).year()) · \(entry.date, format: .relative(presentation: .named))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let note = entry.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        } icon: {
            Image(systemName: entry.isTouch ? "checkmark.circle.fill" : "forward.end.circle")
                .foregroundStyle(entry.isTouch ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .accessibilityElement(children: .combine)
    }
}
