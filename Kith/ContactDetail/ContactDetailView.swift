import SwiftData
import SwiftUI

/// The contact sheet: identity and status up top, then live-edit
/// configuration and the read-only timeline. Pushed, never modal.
///
/// Read-and-configure only: no Logged, no Remind/Skip, no delete here
/// (Contact Detail §8). Everything that advances the clock is a Upcoming action.
struct ContactDetailView: View {
    @Bindable var person: Person
    var showsAlreadyInKithNote = false

    /// Only for the tag menu's options: Contact Detail picks from the
    /// vocabulary rather than growing it. Managed in Settings, not here.
    @Query private var tags: [Tag]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var now = Date.now
    @State private var segment: ContactDetailSegment = .info
    @State private var keyDateEditor: KeyDateEditorItem?
    /// Presented from the Form, not from inside `TagsSection`: a `.sheet` on a
    /// `Section` is applied per row and the presentations cancel each other.
    @State private var isManagingTags = false
    @State private var hasDismissedNote = false

    private var actions: ContactDetailActions {
        ContactDetailActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        let status = person.catchupStatus(at: now)
        let keyDates = DatesSection.ordered(person.keyDates ?? [], now: now)
        let timeline = TimelineEntry.build(for: person)

        List {
            // Info only. The timeline is history, and the identity band above
            // it says nothing about the history — the name is already in the
            // nav bar, and the next-catchup line belongs with the settings
            // that produce it.
            if segment == .info {
                Section {
                    ContactDetailHeader(person: person, status: status, now: now)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            if showsAlreadyInKithNote && !hasDismissedNote {
                Section {
                    Label("Already in Kith", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            switch segment {
            case .info:
                NotifySection(person: person)

                DatesSection(
                    keyDates: keyDates,
                    now: now,
                    onAdd: addKeyDate,
                    onEdit: editKeyDate,
                    onDelete: deleteKeyDate
                )

                TagsSection(
                    tags: person.tags,
                    available: TagVocabulary.options(from: tags, notIn: person.tags),
                    onAdd: addTag,
                    onRemove: removeTag,
                    onManageTags: { isManagingTags = true }
                )

                NotesSection(person: person, onCommit: commitNotes)

            case .timeline:
                TimelineSection(entries: timeline)
            }
        }
        .listStyle(.insetGrouped)
        // Pinned rather than scrolled with the header: a mode switch that
        // scrolls out of sight is a control that hides. Same placement the
        // two feeds give their tag row, and the soft edge is what separates
        // it from the content passing underneath.
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Show", selection: $segment) {
                ForEach(ContactDetailSegment.allCases) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .animation(.default, value: segment)
        .navigationTitle(person.name)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $isManagingTags) {
            ManageTagsView()
        }
        .sheet(item: $keyDateEditor) { item in
            KeyDateEditorView(item: item) { draft in
                saveKeyDate(draft, for: item)
            }
        }
        .onChange(of: person.cadenceRaw) { notifyDidChange() }
        .onChange(of: person.notifyDayRaw) { notifyDidChange() }
        .onChange(of: person.notifyTime) { notifyDidChange() }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .task {
            await dismissNoteAfterDelay()
        }
    }

    // MARK: - Actions

    /// Notify edits write through the binding; this persists and realigns
    /// the reach-out nudge. The header recomputes from the model on its own.
    private func notifyDidChange() {
        withAnimation {
            actions.notifyDidChange(person)
        }
    }

    private func addKeyDate(_ type: KeyDateType) {
        keyDateEditor = .new(type)
    }

    private func editKeyDate(_ keyDate: KeyDate) {
        keyDateEditor = .edit(keyDate)
    }

    private func deleteKeyDate(_ keyDate: KeyDate) {
        withAnimation {
            actions.deleteKeyDate(keyDate)
        }
    }

    private func saveKeyDate(_ draft: KeyDateDraft, for item: KeyDateEditorItem) {
        withAnimation {
            switch item {
            case .new:
                actions.addKeyDate(draft, to: person)
            case .edit(let keyDate):
                actions.updateKeyDate(keyDate, with: draft)
            }
        }
    }

    private func addTag(_ tag: String) {
        withAnimation {
            actions.addTag(tag, to: person)
        }
    }

    private func removeTag(_ tag: String) {
        withAnimation {
            actions.removeTag(tag, from: person)
        }
    }

    private func commitNotes(_ notes: String) {
        actions.commitNotes(notes, for: person)
    }

    /// The duplicate-guard note is transient (Contact Detail §7).
    private func dismissNoteAfterDelay() async {
        guard showsAlreadyInKithNote else { return }
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled else { return }
        withAnimation { hasDismissedNote = true }
    }

    /// Foregrounding refreshes the clock so the header stays honest.
    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        now = .now
    }
}

#Preview("Overdue") {
    let container = SampleData.previewContainer()
    let person = SampleData.previewPerson(named: "Maya Patel", in: container)
    NavigationStack {
        ContactDetailView(person: person)
    }
    .modelContainer(container)
    .environment(ContactImageCache())
}

#Preview("Never, dates only") {
    let container = SampleData.previewContainer()
    let person = SampleData.previewPerson(named: "Dev Kapoor", in: container)
    NavigationStack {
        ContactDetailView(person: person, showsAlreadyInKithNote: true)
    }
    .modelContainer(container)
    .environment(ContactImageCache())
}
