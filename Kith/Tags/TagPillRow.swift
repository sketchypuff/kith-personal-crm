import SwiftUI

/// The tag filter, as a scrolling row of capsules under the toolbar.
///
/// Single-select: tapping the lit pill clears it, same as tapping All. There is
/// no system component for this — a segmented picker can't scroll and forces
/// equal widths — so the row is hand-laid-out, but every pill is a stock
/// `Button` in the glass capsule styles the toolbar already uses.
struct TagPillRow: View {
    let tags: [String]
    @Binding var selection: String?

    /// Scroll id for the All pill, which has no tag of its own.
    private static let allID = "\u{0}all"

    /// Identity space for the pills' glass, so the lit one morphs across the
    /// row rather than fading out in one place and in again in another.
    @Namespace private var glass

    var body: some View {
        if !tags.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    // Adjacent capsules lens against each other here; without a
                    // container each samples the background alone and the row
                    // reads flat.
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            TagPill(title: "All", isSelected: selection == nil, glassID: Self.allID, namespace: glass) {
                                select(nil)
                            }
                            .id(Self.allID)

                            ForEach(tags, id: \.self) { tag in
                                TagPill(title: tag, isSelected: selection == tag, glassID: tag, namespace: glass) {
                                    select(tag)
                                }
                                .id(tag)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // Insets the content, not the scroll view, so pills scroll to
                // the screen edge instead of stopping short of it.
                .contentMargins(.horizontal, 16, for: .scrollContent)
                // A scroll view clips to its bounds, and a glass pill's shadow
                // is wider than the pill. Clipped, it ends in a straight rule
                // across the row. The row already spans the full width, so
                // anything that scrolls out of it is off-screen anyway.
                .scrollClipDisabled()
                .padding(.vertical, 6)
                .onChange(of: selection) { _, tag in
                    withAnimation {
                        proxy.scrollTo(tag ?? Self.allID, anchor: .center)
                    }
                }
            }
        }
    }

    /// Tapping the lit pill clears the filter rather than re-applying it.
    private func select(_ tag: String?) {
        withAnimation {
            selection = (selection == tag) ? nil : tag
        }
    }
}

private struct TagPill: View {
    let title: String
    let isSelected: Bool
    let glassID: String
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Group {
            if isSelected {
                Button(title, action: action)
                    .buttonStyle(.glassProminent)
            } else {
                Button(title, action: action)
                    .buttonStyle(.glass)
            }
        }
        .font(.subheadline)
        .buttonBorderShape(.capsule)
        // Identity within the container, so lighting one pill and clearing
        // another morphs between them rather than cross-fading.
        .glassEffectID(glassID, in: namespace)
        // The one thing a plain Button won't say for itself.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
