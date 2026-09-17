import SwiftUI

struct OnboardingReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: OnboardingPage = .people

    var body: some View {
        NavigationStack {
            OnboardingPagesView(selection: $page)
                .background(.background)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if page.previous != nil {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back", systemImage: "chevron.left", action: goBack)
                                .accessibilityIdentifier("onboarding.replay.back")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: finish)
                            .accessibilityIdentifier("onboarding.replay.done")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button(action: advance) {
                        Text(page.next == nil ? "Done" : "Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .padding()
                    .background(.background)
                    .accessibilityIdentifier("onboarding.replay.continue")
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func advance() {
        if let next = page.next {
            withAnimation(reduceMotion ? nil : .default) { page = next }
        } else {
            finish()
        }
    }

    private func goBack() {
        guard let previous = page.previous else { return }
        withAnimation(reduceMotion ? nil : .default) { page = previous }
    }

    private func finish() {
        dismiss()
    }
}

#Preview("What it does") {
    OnboardingReplayView()
        .roundedTypeface()
}

#Preview("What it does, largest text") {
    OnboardingReplayView()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
        .roundedTypeface()
}
