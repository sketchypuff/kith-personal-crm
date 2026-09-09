import Foundation
import SwiftData
import Testing
@testable import Kith

struct CatchupStatusTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()

    /// Wed 9 Sep 2026, 10:00.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private func days(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: now)!
    }

    private func person(cadence: Cadence = .weekly, lastLogged: Date?) -> Person {
        let person = Person(name: "Test", linkedContactID: "")
        person.cadence = cadence
        person.lastLoggedAt = lastLogged
        person.createdAt = days(-60)
        container.mainContext.insert(person)
        return person
    }

    @Test func neverCadenceHasNoCatchup() {
        let status = person(cadence: .never, lastLogged: nil).catchupStatus(at: now, calendar: calendar)
        #expect(status == .none)
        #expect(!status.isOverdue)
        #expect(status.rosterLabel(now: now, calendar: calendar) == "No catchup scheduled")
    }

    @Test func snoozedWinsOverOverdue() {
        let p = person(lastLogged: days(-20))
        p.remindOn = days(1)
        let status = p.catchupStatus(at: now, calendar: calendar)
        #expect(status == .snoozed)
        #expect(!status.isOverdue)
        #expect(status.rosterLabel(now: now, calendar: calendar) == "Snoozed to tomorrow")
    }

    @Test func overdueCountsWholeDays() {
        let status = person(lastLogged: days(-20)).catchupStatus(at: now, calendar: calendar)
        guard case .overdue(let d) = status else {
            Issue.record("expected overdue, got \(status)")
            return
        }
        #expect(d > 0)
        #expect(status.isOverdue)
        #expect(status.rosterLabel(now: now, calendar: calendar) == "\(d)d overdue")
    }

    @Test func dueEarlierTodayReadsDueToday() {
        // Daily cadence logged yesterday at 06:00 → due today 06:00, now is 10:00.
        let p = person(cadence: .daily, lastLogged: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: days(-1))!)
        p.notifyTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        let status = p.catchupStatus(at: now, calendar: calendar)
        #expect(status == .dueToday)
        #expect(status.isOverdue)
        #expect(status.rosterLabel(now: now, calendar: calendar) == "Due today")
    }

    @Test func upcomingUsesRelativeDay() {
        let tomorrow = CatchupStatus.upcoming(days(1)).rosterLabel(now: now, calendar: calendar)
        #expect(tomorrow == "Next · Tomorrow")

        let laterToday = CatchupStatus.upcoming(calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!)
        #expect(laterToday.rosterLabel(now: now, calendar: calendar) == "Next · Today")

        let saturday = days(3)   // Sat 12 Sep
        let sat = CatchupStatus.upcoming(saturday).rosterLabel(now: now, calendar: calendar)
        #expect(sat == "Next · \(saturday.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated)))")

        let farOut = days(10)
        let far = CatchupStatus.upcoming(farOut).rosterLabel(now: now, calendar: calendar)
        #expect(far == "Next · \(farOut.formatted(Date.FormatStyle(calendar: calendar).day().month(.abbreviated)))")
        #expect(!far.contains("Tomorrow"))
    }

    @Test func detailLabelAddsTimeOnlyForUpcoming() {
        let due = days(1)
        let upcoming = CatchupStatus.upcoming(due).detailLabel(now: now, calendar: calendar)
        #expect(upcoming == "Next catchup · Tomorrow, \(due.formatted(date: .omitted, time: .shortened))")
        #expect(CatchupStatus.overdue(days: 3).detailLabel(now: now, calendar: calendar) == "3d overdue")
    }
}
