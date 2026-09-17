import SwiftUI

/// Call, Message, WhatsApp — three ways out of Kith and into a conversation,
/// sitting directly under the name because that's the moment you decide to
/// reach out.
///
/// Pure: the number is fetched by `ContactDetailView` and handed down, so the
/// section can be left out of the list entirely when there's nothing to show.
/// A dead button is worse than a missing one.
struct QuickActionsRow: View {
    let person: Person
    let number: String
    let onTap: (QuickAction) -> Void

    /// The glyph grows with Dynamic Type; `Image` has no text to scale on its own.
    @ScaledMetric(relativeTo: .title3) private var glyphSize: CGFloat = 20

    /// The actions this number can actually reach, in a fixed order. WhatsApp
    /// drops out when it isn't installed, or when a bare local number can't be
    /// resolved to something international.
    @MainActor
    static func available(for number: String, region: String?) -> [QuickAction] {
        QuickAction.allCases.filter { action in
            action.isAvailable && action.url(number: number, region: region) != nil
        }
    }

    private var actions: [QuickAction] {
        Self.available(for: number, region: Locale.current.region?.identifier)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Button {
                    onTap(action)
                } label: {
                    VStack(spacing: 4) {
                        glyph(for: action)
                        Text(action.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                // Deliberately not the accent. Three tinted buttons under the
                // name read as the primary act on the page, and the primary
                // act here is the cadence below them. The filled background
                // already says "tappable", so the glyph and label are content
                // and nothing more. Set outside the label, which `.bordered`
                // would otherwise repaint with its tint.
                .foregroundStyle(.primary)
                // A rounded rect rather than the default capsule: at this
                // height a capsule reads as two enormous pills, and this is
                // the shape Contacts and Phone use for the same row.
                .buttonBorderShape(.roundedRectangle(radius: 12))
                // A verb on its own would leave VoiceOver asking "call whom?".
                .accessibilityLabel("\(action.title) \(person.name)")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func glyph(for action: QuickAction) -> some View {
        switch action.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.title3)
        case .asset(let name, let fallback):
            // The WhatsApp glyph, when it's in the catalogue; a system symbol
            // standing in when it isn't, so the button never goes missing over
            // an absent file.
            if UIImage(named: name) != nil {
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: glyphSize, height: glyphSize)
            } else {
                Image(systemName: fallback)
                    .font(.title3)
            }
        }
    }
}

#Preview {
    QuickActionsRow(
        person: Person(name: "Maya Patel", linkedContactID: ""),
        number: "+91 98765 43210"
    ) { _ in }
    .padding()
}
