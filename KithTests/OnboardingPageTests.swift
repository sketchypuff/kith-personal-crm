import Testing
@testable import Kith

struct OnboardingPageTests {
    @Test func introductionNavigationHasExplicitStartAndEnd() {
        #expect(OnboardingPage.people.previous == nil)
        #expect(OnboardingPage.people.next == .rhythm)
        #expect(OnboardingPage.rhythm.previous == .people)
        #expect(OnboardingPage.rhythm.next == .privacy)
        #expect(OnboardingPage.privacy.previous == .rhythm)
        #expect(OnboardingPage.privacy.next == nil)
    }

    @Test(arguments: OnboardingPage.allCases)
    func pageNavigationIsReversible(page: OnboardingPage) {
        if let next = page.next {
            #expect(next.previous == page)
        }
        if let previous = page.previous {
            #expect(previous.next == page)
        }
    }

    @Test func replayPagesDoNotIncludeContactSetupOrPermissionRequests() {
        #expect(OnboardingPage.allCases.map(\.step) == [.people, .rhythm, .privacy])
    }
}
