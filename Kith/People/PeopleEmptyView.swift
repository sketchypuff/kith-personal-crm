import Contacts
import SwiftUI

/// The three roster empty states (People §11): nobody yet, no search results,
/// or a tag that hides everyone.
struct PeopleEmptyView: View {
    let hasPeople: Bool
    let searchText: String
    let tag: String?
    let contactsStatus: CNAuthorizationStatus
    let onAdd: () -> Void
    let onClearTag: () -> Void

    @Environment(\.openURL) private var openURL

    private var contactsDenied: Bool {
        contactsStatus == .denied || contactsStatus == .restricted
    }

    var body: some View {
        if !hasPeople {
            ContentUnavailableView {
                Label("No one here yet", systemImage: "person.2")
            } description: {
                if contactsDenied {
                    Text("Adding people needs Contacts access. Allow it in Settings to get started.")
                } else {
                    Text("Add the people you want to stay in touch with, one at a time from your Contacts.")
                }
            } actions: {
                if contactsDenied {
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .font(.headline)
                } else {
                    // First run has no toolbar +, so this is the only way in:
                    // the large control size makes it the screen's obvious target.
                    Button("Add Contact", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .font(.headline)
                }
            }
        } else if !searchText.isEmpty {
            // Explicit text: the overlay sits outside the searchable scope, so the
            // parameterless variant renders a bare "No Results".
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label(tag.map { "No one tagged “\($0)”" } ?? "No one here", systemImage: "tag")
            } description: {
                Text("Everyone else is hidden by the filter.")
            } actions: {
                Button("Clear tag", action: onClearTag)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
