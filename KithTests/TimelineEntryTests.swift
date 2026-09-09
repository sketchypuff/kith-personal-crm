import Foundation
import SwiftData
import Testing
@testable import Kith

struct TimelineEntryTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()

    /// Wed 9 Sep 2026, 10:00.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private func days(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: now)!
    }

    private func person() -> Person {
        let person = Person(name: "Maya", linkedContactID: "")
        container.mainContext.insert(person)
        return person
    }

    private func touch(_ person: Person, daysAgo: Int, note: String? = nil) {
        let touch = Touch(date: days(-daysAgo), note: note)
        touch.person = person
        container.mainContext.insert(touch)
    }

    private func skip(_ person: Person, daysAgo: Int) {
        let marker = SkipMarker(date: days(-daysAgo))
        marker.person = person
        container.mainContext.insert(marker)
    }

    @Test func freshPersonHasEmptyTimeline() {
        #expect(TimelineEntry.build(for: person()).isEmpty)
    }

    @Test func entriesAreNewestFirstWithSkipsInterleaved() {
        let p = person()
        touch(p, daysAgo: 30, note: "Coffee")
        skip(p, daysAgo: 10)
        touch(p, daysAgo: 2)
        touch(p, daysAgo: 60, note: "   ")

        let entries = TimelineEntry.build(for: p)
        #expect(entries.map(\.date) == [days(-2), days(-10), days(-30), days(-60)])
        #expect(entries.map(\.kind) == [.touch(note: nil), .skipped, .touch(note: "Coffee"), .touch(note: nil)])
    }

    @Test func skipsAreVisibleButNeverCountedAsTouches() {
        let p = person()
        touch(p, daysAgo: 1)
        skip(p, daysAgo: 3)
        skip(p, daysAgo: 8)

        let entries = TimelineEntry.build(for: p)
        #expect(entries.count == 3)
        #expect(entries.count(where: \.isTouch) == 1)
        #expect(entries.count(where: \.isTouch) == p.touches?.count)
    }
}
