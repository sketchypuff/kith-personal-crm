import SwiftUI

/// A transient bottom toast with an Undo affordance.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(message)
                .font(.subheadline)
                .lineLimit(1)
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // The app's one floating panel, so the one place a glass surface —
        // rather than a glass control — is right. Glass carries its own
        // shadow, which is why there isn't one here.
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    UndoToast(message: "Checked in · Maya Patel") {}
        .padding()
}
