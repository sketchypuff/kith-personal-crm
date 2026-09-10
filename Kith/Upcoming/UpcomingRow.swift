import SwiftUI

/// Every row — person or date — has the same shape: avatar, name, context
/// line, and the universal check. Tapping the body pushes Contact Detail.
struct UpcomingRow: View {
    let item: UpcomingItem
    let onCheck: () -> Void

    var body: some View {
        NavigationLink(value: item.person) {
            HStack(spacing: 12) {
                ContactAvatarView(
                    name: item.person.name,
                    initials: item.person.initials,
                    contactID: item.person.linkedContactID
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.person.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(subtitleStyle)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                UpcomingCheckButton(label: item.checkAccessibilityLabel, action: onCheck)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(item.person.name)")
    }

    /// Overdue is an informative tint — secondary orange — never red.
    private var subtitleStyle: some ShapeStyle {
        switch item {
        case .reachOut(_, .overdue(let days)) where days > 0:
            AnyShapeStyle(.orange)
        case .keyDate(_, _, _, let days) where days == 0:
            AnyShapeStyle(.tint)
        default:
            AnyShapeStyle(.secondary)
        }
    }
}
