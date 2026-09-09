import Contacts
import SwiftUI

/// The three roster empty states (People §11): nobody yet, no search results,
/// or a filter that hides everyone.
struct PeopleEmptyView: View {
    let hasPeople: Bool
    let searchText: String
    let filter: RosterFilter
    let contactsStatus: CNAuthorizationStatus
    let onAdd: () -> Void
    let onClearFilters: () -> Void

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
                Label(filter.emptyTitle, systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Everyone else is hidden by the filter.")
            } actions: {
                Button("Clear filters", action: onClearFilters)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
