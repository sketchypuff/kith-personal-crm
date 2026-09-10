import SwiftUI

/// The universal check CTA. Stateless: the row itself animates out on tap,
/// and an undone row must come back showing the empty circle.
struct UpcomingCheckButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
