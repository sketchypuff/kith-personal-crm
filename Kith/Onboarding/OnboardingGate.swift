import SwiftData
import SwiftUI

struct OnboardingGate: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(OnboardingState.self) private var onboarding
    @Environment(NotificationConsent.self) private var consent
    @Query private var people: [Person]
    @State private var prepared = false
    @State private var loadError: String?

    private var pendingInvitation: Binding<NotificationInvitation?> {
        Binding(
            get: { prepared && onboarding.step == .finished ? consent.invitation : nil },
            set: { consent.invitation = $0 }
        )
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView {
                    Label("Couldn't open your people", systemImage: "person.2")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Try again", action: prepare)
                }
            } else if onboarding.step == .finished {
                RootTabView()
            } else if !prepared {
                ProgressView("Opening Kith")
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .task { prepare() }
        .onChange(of: people.map(\.id)) {
            guard prepared else { return }
            onboarding.peopleDidChange(people)
            consent.reconcileInvitation(with: people)
        }
        .sheet(item: pendingInvitation) { _ in
            NavigationStack {
                NotificationPermissionView(onFinished: consent.dismissInvitation)
            }
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }

    private func prepare() {
        guard !prepared else { return }
        do {
            let people = try modelContext.fetch(FetchDescriptor<Person>())
            onboarding.prepare(people: people, consent: consent)
            consent.restoreInvitation(with: people)
            loadError = nil
            withAnimation(onboarding.step == .finished || reduceMotion ? nil : .default) {
                prepared = true
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
