import Foundation
import SwiftData

/// Sample people for previews and for exercising the simulator.
/// Launch with `-kith-seed-sample` (DEBUG only) to seed an empty store.
enum SampleData {
    static let launchArgument = "-kith-seed-sample"

    static func seedIfRequested(into context: ModelContext) {
        #if DEBUG
        guard CommandLine.arguments.contains(launchArgument) else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Person>())) ?? 0
        guard count == 0 else { return }
        seed(into: context)
        #endif
    }

    static func previewContainer(caughtUp: Bool = false) -> ModelContainer {
        let container = ModelContainerCoordinator.inMemory()
        if caughtUp {
            seedCaughtUp(into: container.mainContext)
        } else {
            seed(into: container.mainContext)
        }
        return container
    }

    static func seed(into context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }
        func daysAhead(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: now) ?? now }

        let maya = Person(name: "Maya Patel", linkedContactID: "")
        maya.cadence = .weekly
        maya.lastLoggedAt = daysAgo(12)
        maya.tags = ["close friends"]

        let arjun = Person(name: "Arjun Mehta", linkedContactID: "")
        arjun.cadence = .monthly
        arjun.lastLoggedAt = daysAgo(50)
        arjun.tags = ["work"]

        let sam = Person(name: "Sam Rivera", linkedContactID: "")
        sam.cadence = .weekly
        sam.createdAt = daysAgo(16)

        let priya = Person(name: "Priya Shah", linkedContactID: "")
        priya.cadence = .weekly
        priya.lastLoggedAt = daysAgo(1)
        priya.tags = ["family"]
        let priyaBirthday = keyDate(.birthday, on: now, calendar: calendar)

        let dev = Person(name: "Dev Kapoor", linkedContactID: "")
        dev.cadence = .never
        let devAnniversary = keyDate(.anniversary, on: daysAhead(2), calendar: calendar)

        let leah = Person(name: "Leah Chen", linkedContactID: "")
        leah.cadence = .quarterly
        leah.lastLoggedAt = daysAgo(3)
        let leahDate = keyDate(.custom, label: "Work anniversary", on: daysAhead(10), calendar: calendar)
        leahDate.leadTimeDays = 3

        let noor = Person(name: "Noor Ali", linkedContactID: "")
        noor.cadence = .weekly
        noor.lastLoggedAt = daysAgo(20)
        noor.remindOn = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))

        maya.notes = "Loves hiking. Moving to Berlin in October — ask how the flat hunt is going."

        for person in [maya, arjun, sam, priya, dev, leah, noor] {
            context.insert(person)
        }
        priyaBirthday.person = priya
        devAnniversary.person = dev
        leahDate.person = leah
        for date in [priyaBirthday, devAnniversary, leahDate] {
            context.insert(date)
        }

        // History so the contact sheet's timeline has touches and a skip to show.
        let history: [(Person, Date, String?)] = [
            (maya, daysAgo(12), "Coffee at Blue Bottle; she got the Berlin offer."),
            (maya, daysAgo(26), nil),
            (arjun, daysAgo(50), "Intro'd him to Sam for the design role."),
            (priya, daysAgo(1), nil),
            (noor, daysAgo(20), "Ask about the new job next time."),
        ]
        for (person, date, note) in history {
            let touch = Touch(date: date, note: note)
            touch.person = person
            context.insert(touch)
        }
        let mayaSkip = SkipMarker(date: daysAgo(40))
        mayaSkip.person = maya
        context.insert(mayaSkip)

        try? context.save()
    }

    /// The seeded person with this name, for previews of per-person screens.
    static func previewPerson(named name: String, in container: ModelContainer) -> Person {
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.name == name })
        if let person = try? container.mainContext.fetch(descriptor).first {
            return person
        }
        let fallback = Person(name: name, linkedContactID: "")
        container.mainContext.insert(fallback)
        return fallback
    }

    static func seedCaughtUp(into context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let names = ["Maya Patel", "Arjun Mehta", "Priya Shah", "Leah Chen"]
        for name in names {
            let person = Person(name: name, linkedContactID: "")
            person.cadence = .weekly
            person.lastLoggedAt = calendar.date(byAdding: .day, value: -1, to: now)
            context.insert(person)
        }
        try? context.save()
    }

    private static func keyDate(_ type: KeyDateType, label: String? = nil, on date: Date, calendar: Calendar) -> KeyDate {
        let components = calendar.dateComponents([.month, .day], from: date)
        let keyDate = KeyDate()
        keyDate.type = type
        keyDate.customLabel = label
        keyDate.month = components.month ?? 1
        keyDate.day = components.day ?? 1
        keyDate.year = 1990
        return keyDate
    }
}
