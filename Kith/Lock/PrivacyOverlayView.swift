import SwiftUI

/// The opaque cover shown while the scene is inactive or backgrounded with the
/// lock on, so the app-switcher card never shows real data (Settings §6.3).
struct PrivacyOverlayView: View {
    var body: some View {
        Image(systemName: "person.2.fill")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .ignoresSafeArea()
    }
}

#Preview {
    PrivacyOverlayView()
}
