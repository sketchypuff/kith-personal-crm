import SwiftUI

struct OnboardingPagesView: View {
    @Binding var selection: OnboardingPage

    var body: some View {
        TabView(selection: $selection) {
            ForEach(OnboardingPage.allCases) { page in
                OnboardingMessageView(
                    illustration: page.illustration,
                    title: page.title,
                    message: page.message,
                    isSelected: selection == page
                )
                .contentMargins(.bottom, 44, for: .scrollContent)
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .accessibilityIdentifier("onboarding.introduction")
    }
}
