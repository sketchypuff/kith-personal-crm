import SwiftUI

struct OnboardingMessageView: View {
    let illustration: Image
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var detail: LocalizedStringKey?
    var isSelected = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        // Welcome copy must remain scrollable at accessibility text sizes.
        ScrollView {
            VStack(spacing: 24) {
                illustration
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 150 : 300)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: isSelected, initial: true) { _, selected in
            titleFocused = selected
        }
    }
}

#Preview("Your people") {
    let page = OnboardingPage.people
    OnboardingMessageView(
        illustration: page.illustration,
        title: page.title,
        message: page.message
    )
    .roundedTypeface()
}

#Preview("Privacy, largest text") {
    let page = OnboardingPage.privacy
    OnboardingMessageView(
        illustration: page.illustration,
        title: page.title,
        message: page.message
    )
    .environment(\.dynamicTypeSize, .accessibility5)
    .preferredColorScheme(.dark)
    .roundedTypeface()
}
