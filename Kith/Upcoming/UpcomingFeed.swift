import Foundation

/// The ranked Upcoming feed, built in memory from the `@Query` result.
/// Pure and clock-injected so it can be unit tested.
struct UpcomingFeed {
    /// How far ahead this feed looked. A key date's own `leadTimeDays` still
    /// governs when its *notification* fires; it does not decide when the row
    /// becomes visible.
    let horizon: UpcomingHorizon

    /// Key dates inside the horizon, soonest first (today at the top).
    let dates: [UpcomingItem]
    /// Reach-outs inside the horizon, most overdue first, then soonest due.
    /// At most one row per person: their next due date, never the ones after it.
    let reachOuts: [UpcomingItem]
    /// Share of people with a cadence who are not overdue; nil when nobody has a cadence.
    let coverage: Double?

    var hasOverdue: Bool { reachOuts.contains(where: \.isOverdue) }
    var isEmpty: Bool { dates.isEmpty && reachOuts.isEmpty }

    /// Home §3: dates first, then reach-outs. Dates outrank reach-outs because
    /// a missed date is unrecoverable while a late reach-out is elastic.
    var allItems: [UpcomingItem] { dates + reachOuts }

    /// The two segments partition `allItems`: every row is in exactly one.
    func items(for segment: UpcomingSegment) -> [UpcomingItem] {
        switch segment {
        case .upcoming: dates + reachOuts.filter { !$0.isOverdue }
        case .overdue: reachOuts.filter(\.isOverdue)
        }
    }

    static func build(
        people: [Person],
        now: Date = .now,
        calendar: Calendar = .current,
        horizon: UpcomingHorizon = .default
    ) -> UpcomingFeed {
        var dates: [UpcomingItem] = []
        var personIDsWithDateToday: Set<UUID> = []

        for person in people {
            for keyDate in person.keyDates ?? [] {
                guard let occurrence = keyDate.nextOccurrence(from: now, calendar: calendar) else { continue }
                let days = KeyDateEngine.daysUntil(occurrence, from: now, calendar: calendar)
                guard days <= horizon.days else { continue }
                guard !keyDate.isHandled(occurrence: occurrence, calendar: calendar) else { continue }
                dates.append(.keyDate(keyDate: keyDate, person: person, occurrence: occurrence, daysUntil: days))
                if days == 0 { personIDsWithDateToday.insert(person.id) }
            }
        }

        dates.sort { lhs, rhs in
            guard case .keyDate(_, let lp, let lo, _) = lhs, case .keyDate(_, let rp, let ro, _) = rhs else { return false }
            if lo != ro { return lo < ro }
            return lp.name.localizedStandardCompare(rp.name) == .orderedAscending
        }

        // Sorted on the real due date, not on whole days, so two people due the
        // same day keep their notify-time order.
        var pending: [(due: Date, item: UpcomingItem)] = []
        var eligible = 0
        var onTrack = 0

        for person in people where person.cadence != .never {
            eligible += 1
            let overdue = person.isOverdue(at: now)
            if !overdue { onTrack += 1 }

            // A "Remind me tomorrow" hold takes the person off the feed
            // entirely until it lapses, horizon or not.
            guard let due = person.nextDue, !person.isSnoozed(at: now) else { continue }

            let status: UpcomingItem.ReachOutStatus
            if overdue {
                // Already late, so no forward window contains it. Overdue is
                // the app's whole point; narrowing the horizon must never hide it.
                status = .overdue(days: CadenceEngine.daysOverdue(due: due, now: now, calendar: calendar))
            } else {
                let days = KeyDateEngine.daysUntil(due, from: now, calendar: calendar)
                guard days <= horizon.days else { continue }
                status = days == 0 ? .due : .upcoming(days: days)
            }

            // Home §7: a date row today takes precedence over a reach-out that
            // needs attention today; suppress the duplicate. A reach-out due
            // later in the horizon is a separate thing and still shows.
            if status.needsAttention, personIDsWithDateToday.contains(person.id) { continue }

            pending.append((due, .reachOut(person: person, status: status)))
        }

        pending.sort { lhs, rhs in
            if lhs.due != rhs.due { return lhs.due < rhs.due }
            return lhs.item.person.name.localizedStandardCompare(rhs.item.person.name) == .orderedAscending
        }

        // Coverage answers "how am I doing overall", so it counts everyone with
        // a cadence regardless of the horizon the feed was built for.
        let coverage: Double? = eligible == 0 ? nil : Double(onTrack) / Double(eligible)
        return UpcomingFeed(horizon: horizon, dates: dates, reachOuts: pending.map(\.item), coverage: coverage)
    }
}
