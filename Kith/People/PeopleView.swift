import Contacts
import SwiftData
import SwiftUI

/// The roster: everyone in Kith, A–Z, with search, filter, add, and the app's
/// only delete. It finds, opens, adds, and removes — it never logs, snoozes, or skips.
struct PeopleView: View {
    @Query(sort: \Person.name) private var people: [Person]   // ordering is redone in memory
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var filter = RosterFilter()
    @State private var now = Date.now
    @State private var addFlow = AddContactFlowState()
    @State private var contactsStatus = CNContactStore.authorizationStatus(for: .contacts)

    /// Below this many people the roster fits on one screen, so the search
    /// field is hidden: scanning is faster than typing at that size.
    static let searchThreshold = 6

    private var actions: PeopleActions {
        PeopleActions(context: modelContext)
    }

    var body: some View {
        let roster = PeopleRoster.build(people: people, searchText: searchText, filter: filter, now: now)

        NavigationStack(path: $path) {
            List {
                ForEach(roster.entries) { entry in
                    PeopleRow(entry: entry, now: now) {
                        delete(entry.person)
                    }
                    // A plain List draws a separator above its first row, which
                    // reads as a stray rule under the search field.
                    .listRowSeparator(entry.id == roster.entries.first?.id ? .hidden : .automatic, edges: .top)
                }
                if !roster.isEmpty {
                    // Contacts-style trailing footer that scrolls with the content.
                    Section {
                    } footer: {
                        PeopleCountFooter(count: roster.visibleCount, filterSummary: filter.summary)
                    }
                }
            }
            .listStyle(.plain)
            .rosterSearchable(text: $searchText, enabled: people.count >= Self.searchThreshold)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            // A roster that shrinks back below the threshold takes its query
            // with it, so the hidden field can't leave the list filtered.
            .onChange(of: people.count < Self.searchThreshold) { _, hidden in
                if hidden { searchText = "" }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let summary = filter.summary {
                    PeopleFilterStatusBar(summary: summary, onClear: clearFilters)
                }
            }
            .overlay {
                if roster.isEmpty {
                    PeopleEmptyView(
                        hasPeople: !people.isEmpty,
                        searchText: searchText,
                        filter: filter,
                        contactsStatus: contactsStatus,
                        onAdd: beginAdd,
                        onClearFilters: clearFilters
                    )
                }
            }
            .navigationTitle("People")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: Person.self) { person in
                ContactDetailView(person: person)
            }
            .navigationDestination(for: ExistingPersonRoute.self) { route in
                ContactDetailView(person: route.person, showsAlreadyInKithNote: true)
            }
            .toolbar {
                // Both are hidden on first run: there is nothing to filter, and
                // the empty state's Add Contact button is the single call to action.
                if !people.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        PeopleFilterMenu(filter: $filter, tags: roster.allTags)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add", systemImage: "plus", action: beginAdd)
                    }
                }
            }
            .addContactFlow($addFlow, onDuplicate: showExisting)
        }
        .animation(.default, value: filter)
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - Actions

    private func beginAdd() {
        addFlow.begin()
    }

    private func clearFilters() {
        filter.clear()
    }

    private func delete(_ person: Person) {
        withAnimation {
            actions.delete(person)
        }
    }

    private func showExisting(_ person: Person) {
        path.append(ExistingPersonRoute(person: person))
    }

    /// Foregrounding refreshes the clock and re-reads Contacts permission
    /// (the user may have just returned from Settings).
    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        now = .now
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
}

private extension View {
    /// `.searchable` has no "hidden" state, so the modifier is applied or not.
    /// Crossing the threshold rebuilds the list, which is fine: it happens
    /// once, on the add that crosses it.
    @ViewBuilder
    func rosterSearchable(text: Binding<String>, enabled: Bool) -> some View {
        if enabled {
            searchable(text: text, prompt: "Search name, notes, tags")
        } else {
            self
        }
    }
}

#Preview("Roster") {
    PeopleView()
        .modelContainer(SampleData.previewContainer())
        .environment(ContactImageCache())
}

#Preview("Empty") {
    PeopleView()
        .modelContainer(ModelContainerCoordinator.inMemory())
        .environment(ContactImageCache())
}
