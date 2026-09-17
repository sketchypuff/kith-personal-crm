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
    @Environment(\.openURL) private var openURL
    @Environment(ContactPhoneCache.self) private var phoneNumbers
    @Environment(NotificationConsent.self) private var notificationConsent

    @State private var now = Date.now
    @State private var segment: ContactDetailSegment = .info
    @State private var keyDateEditor: KeyDateEditorItem?
    /// Presented from the Form, not from inside `TagsSection`: a `.sheet` on a
    /// `Section` is applied per row and the presentations cancel each other.
    @State private var isManagingTags = false
    @State private var hasDismissedNote = false
    /// Read from Contacts at render time and never stored, the same way the
    /// photo is. Nil means no row: no number on the card, or no access.
    @State private var phoneNumber: String?
    /// Bumped on every foreground so a number added in Contacts while we were
    /// away is picked up without a relaunch.
    @State private var phoneRefresh = 0
    /// Held while the other app is in front. Tapping a quick action logs
    /// immediately, but the confirmation can only be read once Kith is back.
    @State private var pendingUndo: TouchUndoRecord?
    @State private var undo: TouchUndoRecord?
    @State private var reminderWasConfigured = false
    @State private var reminderError: String?

    private var actions: ContactDetailActions {
        ContactDetailActions(context: modelContext, notifications: NotificationScheduler())
    }

    /// One identity for the number lookup: the card it reads, and the counter
    /// that forces a re-read.
    private var phoneLookup: String {
        "\(person.linkedContactID)#\(phoneRefresh)"
    }

    var body: some View {
        let status = person.catchupStatus(at: now)
        let keyDates = DatesSection.ordered(person.keyDates ?? [], now: now)
        let timeline = TimelineEntry.build(for: person)
        // Two readings of the same fact: the header shows only what's worth
        // showing, while the Notify row needs the raw guess to say what
        // Automatic would pick.
        let guessedTimeZone = PersonTimeZone.guess(number: phoneNumber)
        let resolvedTimeZone = PersonTimeZone.resolve(
            identifier: person.timeZoneIdentifier,
            number: phoneNumber,
            now: now
        )

        List {
            // Info only. The timeline is history, and the identity band above
            // it says nothing about the history — the name is already in the
            // nav bar, and the next-catchup line belongs with the settings
            // that produce it.
            if segment == .info {
                Section {
                    ContactDetailHeader(
                        person: person,
                        status: status,
                        now: now,
                        timeZone: resolvedTimeZone?.timeZone
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                // Left out entirely rather than shown empty: there is nothing
                // to reach them on, so there is nothing to draw.
                if let phoneNumber {
                    Section {
                        QuickActionsRow(person: person, number: phoneNumber, onTap: reachOut)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }

            if showsAlreadyInKithNote && !hasDismissedNote {
                Section {
                    Label("Already in Kith", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            switch segment {
            case .info:
                NotifySection(
                    person: person,
                    guessedTimeZone: guessedTimeZone,
                    onSelectCadence: considerReminderInvitation
                )

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
        .overlay(alignment: .bottom) {
            if let undo {
                UndoToast(message: undo.message) {
                    undoQuickAction()
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
        .animation(.default, value: undo?.id)
        .animation(.default, value: phoneNumber)
        .navigationTitle(person.name)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $isManagingTags) {
            ManageTagsView()
        }
        .sheet(item: $keyDateEditor, onDismiss: keyDateEditorDidDismiss) { item in
            KeyDateEditorView(item: item) { draft in
                saveKeyDate(draft, for: item)
            }
        }
        .onChange(of: person.cadenceRaw) { notifyDidChange() }
        .onChange(of: person.notifyDayRaw) { notifyDidChange() }
        .onChange(of: person.notifyTime) { notifyDidChange() }
        .onChange(of: person.timeZoneIdentifier) { timeZoneDidChange() }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .task {
            await dismissNoteAfterDelay()
        }
        .task(id: phoneLookup) {
            await loadPhoneNumber()
        }
        .task(id: undo?.id) {
            await dismissUndoAfterDelay()
        }
        .operationErrorAlert("Couldn't update reminders", message: $reminderError)
    }

    // MARK: - Actions

    /// Logs the catch-up, then hands off to the other app. Both happen on the
    /// tap: the app backgrounds immediately, so there is no "on return" moment
    /// to write it in, and a tap that opened WhatsApp but recorded nothing
    /// would be the worse failure.
    private func reachOut(_ action: QuickAction) {
        guard let phoneNumber,
              let url = action.url(number: phoneNumber, region: Locale.current.region?.identifier)
        else { return }

        // Nil when they've already been caught up with today — a call that
        // rings out followed by a WhatsApp is one catch-up, not two.
        let record = actions.logQuickAction(action, for: person)
        pendingUndo = record

        openURL(url) { opened in
            // Nothing took the URL, so we never left and there is no return to
            // wait for. Show the confirmation now rather than leaving a
            // catch-up logged with no way back.
            guard !opened, let record else { return }
            pendingUndo = nil
            withAnimation { undo = record }
        }
    }

    private func undoQuickAction() {
        guard let record = undo else { return }
        withAnimation {
            actions.undo(record)
            undo = nil
        }
    }

    private func loadPhoneNumber() async {
        if let cached = phoneNumbers.cached(person.linkedContactID) {
            phoneNumber = cached
            return
        }
        // Left as it was while the fetch runs, so a refresh doesn't flicker
        // the row out and back in.
        phoneNumber = await phoneNumbers.number(for: person.linkedContactID)
    }

    private func dismissUndoAfterDelay() async {
        guard undo != nil else { return }
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        withAnimation { undo = nil }
    }

    /// Notify edits write through the binding; this persists and realigns
    /// the reach-out nudge. The header recomputes from the model on its own.
    private func notifyDidChange() {
        withAnimation {
            actions.notifyDidChange(person)
        }
    }

    /// The timezone only changes what the header reads, never when anything
    /// fires, so this persists and stops there.
    private func timeZoneDidChange() {
        withAnimation {
            actions.timeZoneDidChange(person)
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
        reminderWasConfigured = draft.reminderEnabled
    }

    private func keyDateEditorDidDismiss() {
        guard reminderWasConfigured else { return }
        reminderWasConfigured = false
        considerReminderInvitation()
    }

    private func considerReminderInvitation() {
        do {
            try modelContext.save()
            notificationConsent.considerReminder(for: person)
        } catch {
            reminderError = error.localizedDescription
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

    /// Foregrounding refreshes the clock so the header stays honest, and is
    /// the one moment a quick action's confirmation can actually be read —
    /// the tap itself left for another app before a toast could be seen.
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            now = .now
            // A number added in Contacts while we were away should show up.
            phoneNumbers.invalidate(person.linkedContactID)
            phoneRefresh += 1
            if let record = pendingUndo {
                pendingUndo = nil
                withAnimation { undo = record }
            }
        case .background:
            undo = nil
        default:
            break
        }
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
    .environment(ContactPhoneCache())
    .environment(NotificationConsent())
}

#Preview("Never, dates only") {
    let container = SampleData.previewContainer()
    let person = SampleData.previewPerson(named: "Dev Kapoor", in: container)
    NavigationStack {
        ContactDetailView(person: person, showsAlreadyInKithNote: true)
    }
    .modelContainer(container)
    .environment(ContactImageCache())
    .environment(ContactPhoneCache())
    .environment(NotificationConsent())
}
