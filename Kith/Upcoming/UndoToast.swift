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
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    UndoToast(message: "Checked in · Maya Patel") {}
        .padding()
}
