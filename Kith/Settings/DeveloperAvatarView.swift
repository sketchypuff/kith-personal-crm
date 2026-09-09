import SwiftUI

/// The bundled developer photo in a circle, or the system placeholder while
/// the `DeveloperAvatar` image set is still empty.
struct DeveloperAvatarView: View {
    var body: some View {
        Group {
            if let image = UIImage(named: DeveloperProfile.avatarAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(.circle)
        .accessibilityLabel("Photo of \(DeveloperProfile.name)")
    }
}
