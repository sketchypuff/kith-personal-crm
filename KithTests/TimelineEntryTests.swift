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

    private func touch(_ person: Person, daysAgo: Int, note: String? = nil, kind: TouchKind = .reachedOut) {
        let touch = Touch(date: days(-daysAgo), note: note)
        touch.kind = kind
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
        #expect(entries.map(\.kind) == [
            .touch(.reachedOut, note: nil),
            .skipped,
            .touch(.reachedOut, note: "Coffee"),
            .touch(.reachedOut, note: nil),
        ])
    }

    @Test func quickActionTouchesRememberHowYouGotInTouch() {
        let p = person()
        touch(p, daysAgo: 1, kind: .whatsapp)
        touch(p, daysAgo: 2, kind: .messaged)
        touch(p, daysAgo: 3, kind: .called)
        touch(p, daysAgo: 4)
        skip(p, daysAgo: 5)

        let entries = TimelineEntry.build(for: p)
        #expect(entries.map(\.title) == ["WhatsApp", "Messaged", "Called", "Reached out", "Skipped"])
        // A quick action is still a real touch, never a skip.
        #expect(entries.count(where: \.isTouch) == 4)
    }

    /// A build that predates a case reads it as a plain catch-up rather than
    /// breaking — the reason these ride an existing raw string.
    @Test func anUnknownKindDegradesToReachedOut() {
        let p = person()
        let touch = Touch(date: days(-1))
        touch.kindRaw = "carrierPigeon"
        touch.person = p
        container.mainContext.insert(touch)

        #expect(TimelineEntry.build(for: p).first?.title == "Reached out")
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
