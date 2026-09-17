import Foundation
import SwiftData
import Testing
@testable import Kith

struct ContactDetailActionsTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()
    let recorder = NotificationRecorder()

    /// Wed 9 Sep 2026, 10:00.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    /// The Settings default reminder time: 9:30 AM.
    var reminderTime: Date {
        calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now)!
    }

    private func actions(notificationsEnabled: Bool = true) -> ContactDetailActions {
        ContactDetailActions(
            context: container.mainContext,
            notifications: NotificationScheduler(recorder: recorder),
            now: { now },
            calendar: calendar,
            defaultReminderTime: { reminderTime },
            notificationsEnabled: { notificationsEnabled }
        )
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func person(cadence: Cadence = .weekly, lastLoggedDaysAgo: Int = 1) -> Person {
        let person = Person(name: "Maya", linkedContactID: "")
        person.cadence = cadence
        person.lastLoggedAt = calendar.date(byAdding: .day, value: -lastLoggedDaysAgo, to: now)
        container.mainContext.insert(person)
        return person
    }

    // MARK: - Quick actions

    @Test func aTappedQuickActionLogsACatchUpAndResetsTheClock() throws {
        let p = person(lastLoggedDaysAgo: 30)
        p.remindOn = calendar.date(byAdding: .day, value: 1, to: now)

        let record = try #require(actions().logQuickAction(.call, for: p))
        #expect(record.touch.kind == .called)
        #expect(p.lastLoggedAt == now)
        #expect(p.remindOn == nil)
        #expect(p.touches?.count == 1)
    }

    @Test func eachButtonRecordsHowYouGotInTouch() throws {
        for (action, kind) in [
            (QuickAction.call, TouchKind.called),
            (.message, .messaged),
            (.whatsapp, .whatsapp),
        ] {
            let p = person(lastLoggedDaysAgo: 30)
            let record = try #require(actions().logQuickAction(action, for: p))
            #expect(record.touch.kind == kind)
        }
    }

    /// A call that rings out followed by a WhatsApp is one catch-up, not two.
    @Test func aSecondTapTheSameDayLogsNothing() {
        let p = person(lastLoggedDaysAgo: 30)
        #expect(actions().logQuickAction(.call, for: p) != nil)
        #expect(actions().logQuickAction(.whatsapp, for: p) == nil)
        #expect(p.touches?.count == 1)
    }

    /// The cap is on today, not on the person: yesterday's catch-up doesn't
    /// stop today's.
    @Test func yesterdaysCatchUpDoesNotBlockTodays() {
        let p = person(lastLoggedDaysAgo: 30)
        let yesterday = Touch(date: calendar.date(byAdding: .day, value: -1, to: now)!)
        yesterday.person = p
        container.mainContext.insert(yesterday)

        #expect(actions().logQuickAction(.call, for: p) != nil)
        #expect(p.touches?.count == 2)
    }

    /// A skip is the opposite of a touch, so it never stands in for one.
    @Test func aSkipTodayDoesNotCountAsACatchUp() {
        let p = person(lastLoggedDaysAgo: 30)
        let marker = SkipMarker(date: now)
        marker.person = p
        container.mainContext.insert(marker)

        #expect(actions().logQuickAction(.message, for: p) != nil)
    }

    @Test func loggingAQuickActionClearsTheNudges() {
        // Not overdue, so there is a future nudge to clear in the first place.
        let p = person(lastLoggedDaysAgo: 1)
        actions().notifyDidChange(p)
        #expect(recorder.pending[p.reachOutNotificationID] != nil)

        actions().logQuickAction(.call, for: p)
        #expect(recorder.pending[p.reachOutNotificationID] == nil)
        #expect(recorder.pending[p.remindTomorrowNotificationID] == nil)
    }

    @Test func undoPutsEverythingBack() throws {
        let p = person(lastLoggedDaysAgo: 30)
        let previousLastLogged = p.lastLoggedAt
        let hold = calendar.date(byAdding: .day, value: 1, to: now)
        p.remindOn = hold

        let record = try #require(actions().logQuickAction(.whatsapp, for: p))
        actions().undo(record)

        #expect(p.lastLoggedAt == previousLastLogged)
        #expect(p.remindOn == hold)
        #expect(p.touches?.isEmpty == true)
    }

    /// Undoing frees the day again, so a mistaken tap doesn't lock the person
    /// out of a real catch-up until tomorrow.
    @Test func undoingReleasesTheOncePerDayCap() throws {
        let p = person(lastLoggedDaysAgo: 30)
        let record = try #require(actions().logQuickAction(.call, for: p))
        actions().undo(record)
        #expect(actions().logQuickAction(.message, for: p) != nil)
    }

    // MARK: - Notify

    @Test func notifyChangeSchedulesReachOutAtNextDue() throws {
        let p = person()
        actions().notifyDidChange(p)
        let due = try #require(p.nextDue)
        #expect(due > now)
        #expect(recorder.pending[p.reachOutNotificationID] == due)
    }

    @Test func switchingToNeverCancelsEveryReachOutNudge() {
        let p = person()
        actions().notifyDidChange(p)
        #expect(recorder.pending[p.reachOutNotificationID] != nil)

        p.cadence = .never
        actions().notifyDidChange(p)
        #expect(recorder.pending.isEmpty)
        #expect(recorder.cancelled.contains(p.reachOutNotificationID))
        #expect(recorder.cancelled.contains(p.remindTomorrowNotificationID))
        #expect(p.catchupStatus(at: now, calendar: calendar) == .none)
    }

    @Test func alreadyOverduePersonGetsNoPastDatedRequest() {
        let p = person(lastLoggedDaysAgo: 20)
        #expect(p.isOverdue(at: now))
        actions().notifyDidChange(p)
        #expect(recorder.pending.isEmpty)
        #expect(recorder.cancelled.contains(p.reachOutNotificationID))
    }

    @Test func notificationsOffSchedulesNoReachOut() {
        let p = person()
        actions(notificationsEnabled: false).notifyDidChange(p)
        #expect(recorder.pending.isEmpty)
    }

    @Test func changingDayAndTimeRealignsTheDueDate() throws {
        let p = person()
        p.notifyDay = .monday
        p.notifyTime = date(9, 9, hour: 7)
        actions().notifyDidChange(p)
        let due = try #require(recorder.pending[p.reachOutNotificationID])
        #expect(calendar.component(.weekday, from: due) == Weekday.monday.rawValue)
        #expect(calendar.component(.hour, from: due) == 7)
    }

    // MARK: - Key dates

    @Test func addKeyDateStoresComponentsLinksPersonAndSchedulesLeadAndDay() throws {
        let p = person()
        var draft = KeyDateDraft(type: .anniversary, month: 9, day: 20)
        draft.leadTimeDays = 3

        let keyDate = actions().addKeyDate(draft, to: p)

        #expect(keyDate.type == .anniversary)
        #expect(keyDate.month == 9)
        #expect(keyDate.day == 20)
        #expect(keyDate.year == nil)
        #expect(keyDate.person === p)
        #expect(p.keyDates?.count == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<KeyDate>()) == 1)

        #expect(recorder.pending[keyDate.leadNotificationID] == date(9, 17, hour: 9, minute: 30))
        #expect(recorder.pending[keyDate.dayOfNotificationID] == date(9, 20, hour: 9, minute: 30))
    }

    @Test func addKeyDateKeepsYearWhenIncluded() {
        let p = person()
        let draft = KeyDateDraft(type: .birthday, month: 4, day: 12, year: 1990)
        let keyDate = actions().addKeyDate(draft, to: p)
        #expect(keyDate.year == 1990)
        #expect(keyDate.month == 4)
        #expect(keyDate.day == 12)
        // Next occurrence is next April, so both requests land in 2027.
        #expect(recorder.pending[keyDate.dayOfNotificationID] == date(4, 12, hour: 9, minute: 30, year: 2027))
    }

    @Test func customDateStoresTrimmedLabel() {
        let p = person()
        var draft = KeyDateDraft(type: .custom, month: 10, day: 1)
        draft.customLabel = "  Work anniversary "
        let keyDate = actions().addKeyDate(draft, to: p)
        #expect(keyDate.customLabel == "Work anniversary")
        #expect(keyDate.label == "Work anniversary")
    }

    @Test func customDraftRequiresLabel() {
        var draft = KeyDateDraft(type: .custom, month: 9, day: 9)
        #expect(!draft.isValid)
        draft.customLabel = "Move-in day"
        #expect(draft.isValid)
        #expect(KeyDateDraft(type: .birthday, month: 9, day: 9).isValid)
    }

    @Test func dayClampsToTheMonthAndLeapDaySurvivesWithoutYear() {
        var draft = KeyDateDraft(type: .anniversary, month: 1, day: 31)
        draft.month = 4
        draft.clampDay(calendar: calendar)
        #expect(draft.day == 30)

        var leap = KeyDateDraft(type: .birthday, month: 2, day: 29)
        leap.clampDay(calendar: calendar)
        #expect(leap.day == 29)
        leap.year = 2023
        leap.clampDay(calendar: calendar)
        #expect(leap.day == 28)

        #expect(KeyDateDraft.daysIn(month: 2, year: nil, calendar: calendar) == 29)
        #expect(KeyDateDraft.daysIn(month: 2, year: 2024, calendar: calendar) == 29)
        #expect(KeyDateDraft.daysIn(month: 11, year: nil, calendar: calendar) == 30)
    }

    @Test func pastLeadIsSkippedButDayOfStillScheduled() {
        let p = person()
        var draft = KeyDateDraft(type: .anniversary, month: 9, day: 10)   // tomorrow
        draft.leadTimeDays = 3                                              // lead day was Sep 7
        let keyDate = actions().addKeyDate(draft, to: p)
        #expect(recorder.pending[keyDate.leadNotificationID] == nil)
        #expect(recorder.pending[keyDate.dayOfNotificationID] == date(9, 10, hour: 9, minute: 30))
    }

    @Test func zeroLeadTimeSchedulesOnlyDayOf() {
        let p = person()
        var draft = KeyDateDraft(type: .anniversary, month: 9, day: 20)
        draft.leadTimeDays = 0
        let keyDate = actions().addKeyDate(draft, to: p)
        #expect(recorder.pending[keyDate.leadNotificationID] == nil)
        #expect(recorder.pending[keyDate.dayOfNotificationID] != nil)
    }

    @Test func reminderToggleOffSchedulesNothing() {
        let p = person()
        var draft = KeyDateDraft(type: .anniversary, month: 9, day: 20)
        draft.reminderEnabled = false
        let keyDate = actions().addKeyDate(draft, to: p)
        #expect(keyDate.reminderEnabled == false)
        #expect(recorder.pending.isEmpty)
    }

    @Test func notificationsOffSchedulesNoKeyDateReminders() {
        let p = person()
        let draft = KeyDateDraft(type: .anniversary, month: 9, day: 20)
        actions(notificationsEnabled: false).addKeyDate(draft, to: p)
        #expect(recorder.pending.isEmpty)
    }

    @Test func updateKeyDateAppliesDraftAndReschedules() {
        let p = person()
        let keyDate = actions().addKeyDate(KeyDateDraft(type: .anniversary, month: 9, day: 20), to: p)
        let originalDay = recorder.pending[keyDate.dayOfNotificationID]

        var draft = KeyDateDraft(keyDate: keyDate)
        draft.month = 10
        draft.day = 5
        draft.leadTimeDays = 7
        actions().updateKeyDate(keyDate, with: draft)

        #expect(keyDate.month == 10)
        #expect(keyDate.day == 5)
        #expect(keyDate.leadTimeDays == 7)
        #expect(recorder.pending[keyDate.dayOfNotificationID] == date(10, 5, hour: 9, minute: 30))
        #expect(recorder.pending[keyDate.dayOfNotificationID] != originalDay)
        #expect(recorder.pending[keyDate.leadNotificationID] == date(9, 28, hour: 9, minute: 30))
    }

    @Test func draftRoundTripsAnExistingDate() {
        let keyDate = KeyDate()
        keyDate.type = .custom
        keyDate.customLabel = "Graduation"
        keyDate.month = 6
        keyDate.day = 15
        keyDate.year = nil
        keyDate.leadTimeDays = 5
        keyDate.reminderEnabled = false

        let draft = KeyDateDraft(keyDate: keyDate)
        #expect(draft.type == .custom)
        #expect(draft.customLabel == "Graduation")
        #expect(draft.year == nil)
        #expect(draft.month == 6)
        #expect(draft.day == 15)
        #expect(draft.leadTimeDays == 5)
        #expect(!draft.reminderEnabled)
    }

    @Test func deleteKeyDateCancelsBothIDsAndRemovesIt() throws {
        let p = person()
        let keyDate = actions().addKeyDate(KeyDateDraft(type: .anniversary, month: 9, day: 20), to: p)
        let leadID = keyDate.leadNotificationID
        let dayID = keyDate.dayOfNotificationID
        #expect(recorder.pending.count == 2)

        actions().deleteKeyDate(keyDate)

        #expect(recorder.pending.isEmpty)
        #expect(recorder.cancelled.contains(leadID))
        #expect(recorder.cancelled.contains(dayID))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<KeyDate>()) == 0)
        #expect(p.keyDates?.isEmpty == true)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Person>()) == 1)
    }

    @Test func datesOrderBirthdayFirstThenSoonest() {
        let birthday = KeyDate()
        birthday.type = .birthday
        birthday.month = 12
        birthday.day = 1

        let soon = KeyDate()
        soon.type = .anniversary
        soon.month = 9
        soon.day = 15

        let later = KeyDate()
        later.type = .custom
        later.customLabel = "Move"
        later.month = 11
        later.day = 2

        let ordered = DatesSection.ordered([later, soon, birthday], now: now, calendar: calendar)
        #expect(ordered.map(\.label) == ["Birthday", "Anniversary", "Move"])
    }

    // MARK: - Tags

    @Test func tagsTrimDedupeAndNeverTouchCadence() {
        let p = person(cadence: .monthly)
        p.notifyDay = .tuesday
        let before = (p.cadenceRaw, p.notifyDayRaw, p.notifyTime, p.nextDue)

        #expect(actions().addTag("  close friends ", to: p))
        #expect(!actions().addTag("Close Friends", to: p))
        #expect(!actions().addTag("   ", to: p))
        #expect(actions().addTag("work", to: p))
        #expect(p.tags == ["Close friends", "Work"])   // starter spelling wins

        actions().removeTag("close friends", from: p)
        #expect(p.tags == ["Work"])

        #expect(p.cadenceRaw == before.0)
        #expect(p.notifyDayRaw == before.1)
        #expect(p.notifyTime == before.2)
        #expect(p.nextDue == before.3)
        #expect(recorder.pending.isEmpty)
    }

    // MARK: - Notes

    @Test func commitNotesWritesOnlyWhenChanged() {
        let p = person()
        actions().commitNotes("Loves hiking.", for: p)
        #expect(p.notes == "Loves hiking.")
        #expect(!container.mainContext.hasChanges)

        actions().commitNotes("Loves hiking.", for: p)
        #expect(!container.mainContext.hasChanges)
        #expect(p.notes == "Loves hiking.")
    }
}
