import SwiftUI

/// Contact photo referenced at render time, with an immediate monogram fallback.
struct ContactAvatarView: View {
    let name: String
    let initials: String
    let contactID: String
    var size: CGFloat = 44

    @Environment(ContactImageCache.self) private var cache
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
                            .foregroundStyle(.tint)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: contactID) {
            image = cache.cached(contactID)
            if image == nil {
                image = await cache.image(for: contactID)
            }
        }
    }
}

#Preview {
    ContactAvatarView(name: "Maya Patel", initials: "MP", contactID: "")
        .environment(ContactImageCache())
}
