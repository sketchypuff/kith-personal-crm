import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingState.self) private var onboarding
    @Environment(NotificationConsent.self) private var consent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var addFlow = AddContactFlowState()

    private var selectedPage: Binding<OnboardingPage> {
        Binding(
            get: { OnboardingPage.allCases.first { $0.step == onboarding.step } ?? .people },
            set: {
                // UIKit can finish a page transition after setup has opened.
                if onboarding.step.isIntroduction { onboarding.show($0.step) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if onboarding.step.isIntroduction {
                    OnboardingPagesView(selection: selectedPage)
                } else if onboarding.step == .notifications {
                    NotificationPermissionView(onFinished: onboarding.finish)
                } else {
                    OnboardingMessageView(
                        illustration: OnboardingPage.people.illustration,
                        title: "Start with one person.",
                        message: "Choose someone you'd like to keep in touch with. Set a rhythm, add a birthday, and pick any tags that fit.",
                        detail: "Kith will ask for Contacts access for photos and call or message shortcuts. You can still add someone if you don't allow access."
                    )
                }
            }
            .background(.background)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if [.rhythm, .privacy, .addPerson].contains(onboarding.step) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left", action: goBack)
                            .accessibilityIdentifier("onboarding.back")
                    }
                }
                if onboarding.step.isIntroduction {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") { onboarding.show(.addPerson) }
                            .accessibilityIdentifier("onboarding.skip")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if onboarding.step != .notifications || onboarding.hasRestoredPeople {
                    VStack(spacing: 12) {
                        if onboarding.hasRestoredPeople {
                            Button("Continue to your people", action: onboarding.finish)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .accessibilityIdentifier("onboarding.restored")
                        } else if onboarding.step.isIntroduction {
                            Button(action: advance) {
                                Text("Continue").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.continue")
                        } else {
                            Button(action: addPerson) {
                                Text("Add your first person").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("onboarding.add")
                            Button(action: onboarding.finish) {
                                Text("I'll do this later")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(.rect)
                            }
                                .accessibilityIdentifier("onboarding.later")
                        }
                    }
                    .font(.headline)
                    .padding()
                    .background(.background)
                }
            }
        }
        .addContactFlow(
            addFlow,
            onDuplicate: { _ in onboarding.foundExistingPerson() },
            onCreated: onboarding.recordSavedPerson,
            onSaved: { onboarding.saved($0, consent: consent) }
        )
    }

    private func addPerson() {
        addFlow.begin()
    }

    private func advance() {
        withAnimation(reduceMotion ? nil : .default) {
            switch onboarding.step {
            case .people: onboarding.show(.rhythm)
            case .rhythm: onboarding.show(.privacy)
            case .privacy: onboarding.show(.addPerson)
            default: break
            }
        }
    }

    private func goBack() {
        withAnimation(reduceMotion ? nil : .default) {
            switch onboarding.step {
            case .rhythm: onboarding.show(.people)
            case .privacy: onboarding.show(.rhythm)
            case .addPerson: onboarding.show(.privacy)
            default: break
            }
        }
    }
}
