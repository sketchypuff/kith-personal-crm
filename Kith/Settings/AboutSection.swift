import SwiftUI

/// Identity rows (Settings §8): name, version, the developer card, and — once
/// the listing exists — a link to leave an App Store review.
struct AboutSection: View {
    @State private var isPresentingDeveloper = false

    var body: some View {
        Section("About") {
            LabeledContent("Name", value: "Kith")
            LabeledContent("Version", value: Bundle.main.versionDescription)

            Button(action: showDeveloper) {
                HStack {
                    Label("Made by \(DeveloperProfile.name)", systemImage: "person.crop.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.primary)
            }

            if let reviewURL = AppStoreListing.writeReviewURL {
                Link(destination: reviewURL) {
                    Label("Review in App Store", systemImage: "star")
                }
                .foregroundStyle(.primary)
            }
        }
        .sheet(isPresented: $isPresentingDeveloper) {
            DeveloperCardView()
        }
    }

    private func showDeveloper() {
        isPresentingDeveloper = true
    }
}
