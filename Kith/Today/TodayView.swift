import SwiftData
import SwiftUI

/// The root screen: one prioritized feed where every row resolves to one tap.
struct TodayView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var path = NavigationPath()
    @State private var segment: TodaySegment = .all
    @State private var now = Date.now
    @State private var undo: TodayUndoRecord?
    @State private var checkCount = 0
    @State private var addFlow = AddContactFlowState()

    private var feed: TodayFeed {
        TodayFeed.build(people: people, now: now)
    }

    private var actions: TodayActions {
        TodayActions(context: modelContext, notifications: NotificationScheduler())
    }

    var body: some View {
        let feed = feed
        let activeSegment = feed.hasOverdue ? segment : .all
        let items = feed.items(for: activeSegment)

        NavigationStack(path: $path) {
            List(items) { item in
                TodayRow(item: item) {
                    check(item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if case .reachOut(let person, _) = item {
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
                        ForEach(TodaySegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    // Don't let the background extend up under the nav bar and cover the large title.
                    .background(.bar, ignoresSafeAreaEdges: [])
                }
            }
            .overlay {
                if items.isEmpty {
                    TodayEmptyView(
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
            .navigationTitle("Today")
            .toolbarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationDestination(for: Person.self) { person in
                ContactDetailView(person: person)
            }
            .navigationDestination(for: ExistingPersonRoute.self) { route in
                ContactDetailView(person: route.person, showsAlreadyInKithNote: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus", action: beginAdd)
                        .buttonStyle(.borderedProminent)   // the screen's primary CTA, accent-tinted
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

    private func check(_ item: TodayItem) {
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
    TodayView()
        .modelContainer(SampleData.previewContainer())
        .environment(ContactImageCache())
}

#Preview("Caught up") {
    TodayView()
        .modelContainer(SampleData.previewContainer(caughtUp: true))
        .environment(ContactImageCache())
}
