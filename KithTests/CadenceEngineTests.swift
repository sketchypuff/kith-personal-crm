import Foundation
import Testing
@testable import Kith

struct CadenceEngineTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var sixPM: Date { date(2026, 1, 1, 18, 0) }

    @Test func neverHasNoDueDate() {
        #expect(CadenceEngine.advance(date(2026, 9, 9), by: .never, alignedTo: .saturday, at: sixPM, calendar: calendar) == nil)
    }

    @Test func weeklyAlignsToSaturdayAtNotifyTime() {
        // Wed 9 Sep 2026 + 7d = Wed 16 Sep → next Saturday is 19 Sep.
        let due = CadenceEngine.advance(date(2026, 9, 9), by: .weekly, alignedTo: .saturday, at: sixPM, calendar: calendar)
        #expect(due == date(2026, 9, 19, 18, 0))
    }

    @Test func weeklyLoggedOnSaturdayIsExactlyOneWeekOut() {
        // Sat 12 Sep 2026 + 7d = Sat 19 Sep, already aligned.
        let due = CadenceEngine.advance(date(2026, 9, 12), by: .weekly, alignedTo: .saturday, at: sixPM, calendar: calendar)
        #expect(due == date(2026, 9, 19, 18, 0))
    }

    @Test func dailyIgnoresNotifyDayButKeepsTime() {
        let due = CadenceEngine.advance(date(2026, 9, 9, 8, 30), by: .daily, alignedTo: .saturday, at: sixPM, calendar: calendar)
        #expect(due == date(2026, 9, 10, 18, 0))
    }

    @Test func monthlyAdvancesOneMonthThenAligns() {
        // 9 Sep + 1 month = Fri 9 Oct 2026 → Sat 10 Oct.
        let due = CadenceEngine.advance(date(2026, 9, 9), by: .monthly, alignedTo: .saturday, at: sixPM, calendar: calendar)
        #expect(due == date(2026, 10, 10, 18, 0))
    }

    @Test func daysOverdueCountsCalendarDays() {
        let due = date(2026, 9, 5, 18, 0)
        #expect(CadenceEngine.daysOverdue(due: due, now: date(2026, 9, 5, 23, 0), calendar: calendar) == 0)
        #expect(CadenceEngine.daysOverdue(due: due, now: date(2026, 9, 8, 1, 0), calendar: calendar) == 3)
    }

    @Test func keyDateOccurrenceIncludesToday() {
        let today = date(2026, 9, 9, 15, 0)
        let occurrence = KeyDateEngine.nextOccurrence(month: 9, day: 9, from: today, calendar: calendar)
        #expect(occurrence == calendar.startOfDay(for: today))
        #expect(KeyDateEngine.daysUntil(occurrence!, from: today, calendar: calendar) == 0)
    }

    @Test func keyDateOccurrenceRollsToNextYearOncePassed() {
        let today = date(2026, 9, 9)
        let occurrence = KeyDateEngine.nextOccurrence(month: 9, day: 8, from: today, calendar: calendar)
        #expect(occurrence == date(2027, 9, 8, 0, 0))
    }
}
