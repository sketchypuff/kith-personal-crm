import SwiftUI

/// Identity rows (Settings §8): name, version, the developer card, and — once
/// the listing exists — a link to leave an App Store review.
///
/// The developer sheet is presented by `SettingsView` on the `Form`, not here:
/// a modifier on a `Section` is applied to every row of that section, so a
/// `.sheet` written here would run one presentation per row and they cancel
/// each other out the moment the button is tapped.
struct AboutSection: View {
    var onShowDeveloper: () -> Void

    var body: some View {
        Section("About") {
            LabeledContent("Name", value: "Kith")
            LabeledContent("Version", value: Bundle.main.versionDescription)

            Button(action: onShowDeveloper) {
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
    }
}
