import Foundation

/// The ranked Today feed, built in memory from the `@Query` result.
/// Pure and clock-injected so it can be unit tested.
struct TodayFeed {
    /// Key dates within their lead window, soonest first (today at the top).
    let dates: [TodayItem]
    /// Overdue people, most overdue first.
    let reachOuts: [TodayItem]
    /// Share of people with a cadence who are not overdue; nil when nobody has a cadence.
    let coverage: Double?

    var hasOverdue: Bool { !reachOuts.isEmpty }
    var isEmpty: Bool { dates.isEmpty && reachOuts.isEmpty }

    /// Home §3: All = dates first, then overdue people. Dates outrank reach-outs
    /// because a missed date is unrecoverable while a late reach-out is elastic.
    func items(for segment: TodaySegment) -> [TodayItem] {
        switch segment {
        case .all: dates + reachOuts
        case .upcoming: dates
        case .overdue: reachOuts
        }
    }

    static func build(people: [Person], now: Date = .now, calendar: Calendar = .current) -> TodayFeed {
        var dates: [TodayItem] = []
        var personIDsWithDateToday: Set<UUID> = []

        for person in people {
            for keyDate in person.keyDates ?? [] {
                guard let occurrence = keyDate.nextOccurrence(from: now, calendar: calendar) else { continue }
                let days = KeyDateEngine.daysUntil(occurrence, from: now, calendar: calendar)
                guard days <= keyDate.leadTimeDays else { continue }
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

        var reachOuts: [TodayItem] = []
        var eligible = 0
        var onTrack = 0

        for person in people where person.cadence != .never {
            eligible += 1
            guard let due = person.nextDue, person.isOverdue(at: now) else {
                onTrack += 1
                continue
            }
            // Home §7: a date row today takes precedence; suppress the duplicate reach-out.
            guard !personIDsWithDateToday.contains(person.id) else { continue }
            let days = CadenceEngine.daysOverdue(due: due, now: now, calendar: calendar)
            reachOuts.append(.reachOut(person: person, daysOverdue: days))
        }

        reachOuts.sort { lhs, rhs in
            guard case .reachOut(let lp, let ld) = lhs, case .reachOut(let rp, let rd) = rhs else { return false }
            if ld != rd { return ld > rd }
            return lp.name.localizedStandardCompare(rp.name) == .orderedAscending
        }

        let coverage: Double? = eligible == 0 ? nil : Double(onTrack) / Double(eligible)
        return TodayFeed(dates: dates, reachOuts: reachOuts, coverage: coverage)
    }
}
