import SwiftUI

/// The developer card (Settings §8.2): a presented sheet — the only secondary
/// surface in Settings — with the avatar, name, bio, and the social rows.
/// Nothing here is saved; Close just dismisses.
struct DeveloperCardView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeveloperCardHeader()
                }
                .listRowBackground(Color.clear)

                Section("Socials") {
                    ForEach(DeveloperProfile.links) { link in
                        if let url = link.url {
                            Link(destination: url) {
                                Label(link.network, systemImage: link.systemImage)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("About the developer")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark", action: dismissCard)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func dismissCard() {
        dismiss()
    }
}

#Preview {
    DeveloperCardView()
}
