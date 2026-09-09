import SwiftUI

/// The minimal native gate (Settings §6.4): app glyph, an Unlock affordance,
/// and nothing else — no data is loaded behind it. Prompts on appear; the
/// button is the retry after a cancel or failure.
struct LockScreenView: View {
    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var availability: LockAvailability = .passcodeOnly

    private let authenticator = LockAuthenticator()

    var body: some View {
        ContentUnavailableView {
            Label("Kith is locked", systemImage: "lock.fill")
        } description: {
            Text("Unlock to see your people.")
        } actions: {
            Button("Unlock", systemImage: availability.unlockSymbolName, action: unlock)
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
        }
        .background(.background)
        .task {
            availability = authenticator.availability()
            await authenticate()
        }
    }

    private func unlock() {
        Task {
            await authenticate()
        }
    }

    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: "Unlock Kith to see your people.") {
            onUnlock()
        }
    }
}

#Preview {
    LockScreenView {}
}
