import SwiftUI

/// Avatar, name, and bio at the top of the developer card.
struct DeveloperCardHeader: View {
    var body: some View {
        VStack {
            DeveloperAvatarView()
            Text(DeveloperProfile.name)
                .font(.title)
                .bold()
            Text(DeveloperProfile.bio)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
