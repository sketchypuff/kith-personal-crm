import SwiftData
import SwiftUI

/// The root screen: one prioritized 30-day feed where every row resolves to one tap.
struct UpcomingView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var path = NavigationPath()
    @State private var segment: UpcomingSegment = .upcoming
    @State private var now = Date.now
    @State private var undo: UpcomingUndoRecord?
    @State private var checkCount = 0
    @State private var addFlow = AddContactFlowState()

    private var feed: UpcomingFeed {
        UpcomingFeed.build(people: people, now: now)
    }

    private var actions: UpcomingActions {
        UpcomingActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        let feed = feed
        // With nothing overdue the picker is hidden, and Upcoming is the whole feed.
        let activeSegment: UpcomingSegment = feed.hasOverdue ? segment : .upcoming
        let items = feed.items(for: activeSegment)

        NavigationStack(path: $path) {
            List(items) { item in
                UpcomingRow(item: item) {
                    check(item)
                }
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
                if feed.hasOverdue {
                    Picker("Show", selection: $segment) {
                        ForEach(UpcomingSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .overlay {
                if items.isEmpty {
                    UpcomingEmptyView(
                        feed: feed,
                        segment: activeSegment,
                        hasPeople: !people.isEmpty,
                        onAdd: beginAdd
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
            .navigationTitle("Upcoming")
            .toolbarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
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
                            .buttonStyle(.borderedProminent)   // the screen's primary CTA, accent-tinted
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
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - Actions

    private func beginAdd() {
        addFlow.begin()
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
