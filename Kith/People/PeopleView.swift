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
    @State private var tag: String?
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
        let roster = PeopleRoster.build(people: people, searchText: searchText, tag: tag, now: now)

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
                TagPillRow(tags: roster.allTags, selection: $tag)
            }
            // The roster softens under the pill row and the search field rather
            // than cutting against them, and under the tab bar at the far end.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .overlay {
                if roster.isEmpty {
                    PeopleEmptyView(
                        hasPeople: !people.isEmpty,
                        searchText: searchText,
                        tag: tag,
                        contactsStatus: contactsStatus,
                        onAdd: beginAdd,
                        onClearTag: clearTag
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
                // Hidden on first run: the empty state's Add Contact button is
                // the single call to action until someone has been added.
                if !people.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add", systemImage: "plus", action: beginAdd)
                            .buttonStyle(.glassProminent)   // the screen's primary CTA, accent-tinted
                    }
                }
            }
            .addContactFlow($addFlow, onDuplicate: showExisting)
        }
        .animation(.default, value: tag)
        // Untagging the last person carrying the lit tag would otherwise leave
        // the roster scoped to a pill that no longer exists.
        .onChange(of: roster.allTags) { _, tags in
            if let tag, !tags.contains(tag) { clearTag() }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - Actions

    private func beginAdd() {
        addFlow.begin()
    }

    private func clearTag() {
        withAnimation {
            tag = nil
        }
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
                // Collapses to a glass magnifier beside Add and expands on tap,
                // giving the roster back the row the field used to occupy.
                .searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }
}

#Preview("Roster") {
    PeopleView()
        .modelContainer(SampleData.previewContainer())
        .environment(ContactImageCache())
        .environment(ContactPhoneCache())
}

#Preview("Empty") {
    PeopleView()
        .modelContainer(ModelContainerCoordinator.inMemory())
        .environment(ContactImageCache())
        .environment(ContactPhoneCache())
}
