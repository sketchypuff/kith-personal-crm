import SwiftData
import SwiftUI

/// The root screen: one prioritized 30-day feed where every row resolves to one tap.
struct UpcomingView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var path = NavigationPath()
    @State private var mode: UpcomingMode = .upcoming
    @State private var horizon: UpcomingHorizon = .default
    @State private var tag: String?
    @State private var now = Date.now
    @State private var undo: UpcomingUndoRecord?
    @State private var checkCount = 0
    @State private var addFlow = AddContactFlowState()

    private var feed: UpcomingFeed {
        UpcomingFeed.build(people: people, now: now, horizon: horizon, tag: tag)
    }

    /// Read from everyone, never from the scoped feed, so picking a tag can't
    /// collapse the row down to the one pill that is already lit.
    private var tags: [String] {
        TagVocabulary.all(in: people)
    }

    private var actions: UpcomingActions {
        UpcomingActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        let feed = feed
        let items = feed.items(for: mode)

        NavigationStack(path: $path) {
            List(items) { item in
                UpcomingRow(item: item) {
                    check(item)
                }
                // A plain List draws a separator above its first row, which
                // reads as a stray rule under the picker.
                .listRowSeparator(item.id == items.first?.id ? .hidden : .automatic, edges: .top)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Only rows asking for something today: holding or skipping
                    // a reach-out that isn't due yet would do nothing.
                    if case .reachOut(let person, _) = item, item.isActionable {
                        Button("Remind me tomorrow", systemImage: "clock.arrow.circlepath") {
                            remindTomorrow(person)
                        }
                        .tint(.indigo)
                        Button("Skip", systemImage: "forward.end") {
                            skip(person)
                        }
                        .tint(.gray)
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top, spacing: 0) {
                TagPillRow(tags: tags, selection: $tag)
            }
            .overlay {
                if items.isEmpty {
                    UpcomingEmptyView(
                        feed: feed,
                        mode: mode,
                        hasPeople: !people.isEmpty,
                        tag: tag,
                        onAdd: beginAdd,
                        onClearTag: clearTag,
                        onShowOverdue: { mode = .overdue }
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if let undo {
                    UndoToast(message: undo.message) {
                        undoLastCheck()
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // The title names the mode, and the dropdown is how the mode changes.
            .navigationTitle(mode.rawValue)
            // Named by the same value that bounds the feed, so the header can't
            // claim a window the list isn't showing. Overdue isn't bounded at all.
            .horizonSubtitle(horizon.label, when: mode.usesHorizon)
            .toolbarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                Picker("Show", selection: $mode) {
                    ForEach(UpcomingMode.allCases) { item in
                        // Overdue carries its count, because it's now the only
                        // hint that anyone is late while the feed looks calm.
                        Text(label(for: item, in: feed)).tag(item)
                    }
                }
                .pickerStyle(.inline)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
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
                    // Overdue ignores the window, so offering to narrow it there
                    // would be a control that does nothing.
                    if mode.usesHorizon {
                        ToolbarItem(placement: .topBarTrailing) {
                            UpcomingFilterMenu(horizon: $horizon)
                        }
                        // Splits the two into separate glass capsules: narrowing the
                        // feed and adding a person are unrelated acts.
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add", systemImage: "plus", action: beginAdd)
                            .buttonStyle(.glassProminent)   // the screen's primary CTA, accent-tinted
                    }
                }
            }
            .addContactFlow($addFlow, onDuplicate: showExisting)
        }
        .sensoryFeedback(.success, trigger: checkCount)
        .animation(.default, value: undo?.id)
        .task(id: undo?.id) {
            await dismissUndoAfterDelay()
        }
        // Untagging the last person carrying the lit tag would otherwise leave
        // the feed scoped to a pill that no longer exists.
        .onChange(of: tags) { _, tags in
            if let tag, !tags.contains(tag) { clearTag() }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    /// "Overdue (3)" when anyone is late, plain names otherwise.
    private func label(for mode: UpcomingMode, in feed: UpcomingFeed) -> String {
        let count = feed.items(for: mode).count
        guard mode == .overdue, count > 0 else { return mode.rawValue }
        return "\(mode.rawValue) (\(count))"
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

    private func check(_ item: UpcomingItem) {
        withAnimation {
            switch item {
            case .reachOut(let person, _):
                undo = actions.log(person)
            case .keyDate(let keyDate, let person, _, _):
                undo = actions.handle(keyDate, for: person)
            }
        }
        checkCount += 1
    }

    private func undoLastCheck() {
        guard let record = undo else { return }
        withAnimation {
            actions.undo(record)
            undo = nil
        }
    }

    private func remindTomorrow(_ person: Person) {
        withAnimation {
            actions.remindTomorrow(person)
        }
    }

    private func skip(_ person: Person) {
        withAnimation {
            actions.skip(person)
        }
    }

    private func showExisting(_ person: Person) {
        path.append(ExistingPersonRoute(person: person))
    }

    private func dismissUndoAfterDelay() async {
        guard undo != nil else { return }
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        withAnimation { undo = nil }
    }

    /// Home §7: backgrounding commits the check. Foregrounding refreshes the clock.
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            now = .now
        case .background:
            undo = nil
        default:
            break
        }
    }
}

private extension View {
    /// `.navigationSubtitle` has no "hidden" state, and an empty string still
    /// reserves the line, so the modifier is applied or it isn't.
    @ViewBuilder
    func horizonSubtitle(_ label: String, when shown: Bool) -> some View {
        if shown {
            navigationSubtitle(label)
        } else {
            self
        }
    }
}

#Preview("Feed") {
    UpcomingView()
        .modelContainer(SampleData.previewContainer())
        .environment(ContactImageCache())
}

#Preview("Caught up") {
    UpcomingView()
        .modelContainer(SampleData.previewContainer(caughtUp: true))
        .environment(ContactImageCache())
}
