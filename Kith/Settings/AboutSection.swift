import SwiftUI

/// Identity and reassurance (Settings §8): name, version, the privacy promise,
/// and the one row that opens the developer card. Static content, no keys.
struct AboutSection: View {
    @State private var isPresentingDeveloper = false

    var body: some View {
        Section("About") {
            LabeledContent("Name", value: "Kith")
            LabeledContent("Version", value: Bundle.main.versionDescription)

            Button(action: showDeveloper) {
                HStack {
                    Label("About the developer", systemImage: "person.crop.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
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
