import Foundation
import Testing
@testable import Kith

/// Kith never asks where someone is; it works it out from the number already
/// on their card. A wrong answer here is worse than none, because nothing on
/// screen marks the line as a guess — so most of this suite is about what the
/// resolver refuses to answer.
struct PersonTimeZoneTests {

    /// Somewhere far enough from every zone under test that "ahead" and
    /// "behind" can't come out right by accident.
    private let london = TimeZone(identifier: "Europe/London")!
    /// Spelled the way Foundation spells it. tzdb renamed this zone to
    /// `Asia/Kolkata`, but `knownTimeZoneIdentifiers` still lists the old name,
    /// and `TimeZone` compares by string — so the two are unequal objects for
    /// the same place.
    private let india = TimeZone(identifier: "Asia/Calcutta")!

    // MARK: - Guessing from the number

    @Test func guessesFromAnInternationalNumber() {
        #expect(PersonTimeZone.guess(number: "+49 30 901820") == TimeZone(identifier: "Europe/Berlin"))
    }

    @Test func guessesFromTheOtherInternationalNotation() {
        #expect(PersonTimeZone.guess(number: "0049 30 901820") == TimeZone(identifier: "Europe/Berlin"))
    }

    @Test func readsPastPunctuationAndSpacing() {
        #expect(PersonTimeZone.guess(number: "+81 (3) 3224-5000") == TimeZone(identifier: "Asia/Tokyo"))
    }

    /// The whole point of the longest-prefix walk: `376` must not be read as a
    /// code beginning `3`.
    @Test func prefersTheLongestMatchingCallingCode() {
        #expect(PersonTimeZone.guess(number: "+376 800020") == TimeZone(identifier: "Europe/Andorra"))
        #expect(PersonTimeZone.guess(number: "+370 5 210 7777") == TimeZone(identifier: "Europe/Vilnius"))
    }

    @Test func refusesACountryThatKeepsMoreThanOneTime() {
        // Each of these spans several zones, and a phone number says which
        // country someone is in, never which part of it.
        #expect(PersonTimeZone.guess(number: "+1 202 456 1111") == nil)      // United States
        #expect(PersonTimeZone.guess(number: "+61 2 9374 4000") == nil)      // Australia
        #expect(PersonTimeZone.guess(number: "+55 11 3060 9800") == nil)     // Brazil
        #expect(PersonTimeZone.guess(number: "+7 495 123 4567") == nil)      // Russia
    }

    /// A local number is dialled from wherever this phone already is, so it
    /// carries no information about its owner. It must not fall back to the
    /// reader's own zone.
    @Test func refusesALocalNumber() {
        #expect(PersonTimeZone.guess(number: "020 7946 0018") == nil)
        #expect(PersonTimeZone.guess(number: "9876543210") == nil)
    }

    @Test func refusesSomethingThatIsntANumber() {
        #expect(PersonTimeZone.guess(number: nil) == nil)
        #expect(PersonTimeZone.guess(number: "") == nil)
        #expect(PersonTimeZone.guess(number: "call the office") == nil)
    }

    @Test func refusesSomethingTooShortToBeANumber() {
        #expect(PersonTimeZone.guess(number: "+44") == nil)
        #expect(PersonTimeZone.guess(number: "+4420") == nil)
    }

    /// A country that legally keeps one time is answered even though the tz
    /// database records a second zone for local practice.
    @Test func answersACountryWithOneLegalTime() {
        #expect(PersonTimeZone.guess(number: "+86 10 6512 3456") == TimeZone(identifier: "Asia/Shanghai"))
    }

    // MARK: - Resolving

    @Test func aChosenZoneWinsOverTheNumber() {
        let resolved = PersonTimeZone.resolve(
            identifier: "America/Chicago",
            number: "+49 30 901820",
            device: london
        )
        #expect(resolved?.timeZone == TimeZone(identifier: "America/Chicago"))
        #expect(resolved?.isGuess == false)
    }

    @Test func aGuessIsMarkedAsOne() {
        let resolved = PersonTimeZone.resolve(identifier: nil, number: "+91 22 2202 1111", device: london)
        #expect(resolved?.timeZone == india)
        #expect(resolved?.isGuess == true)
    }

    @Test func anUnreadableChosenZoneFallsBackToTheGuess() {
        let resolved = PersonTimeZone.resolve(
            identifier: "Middle/Earth",
            number: "+91 22 2202 1111",
            device: london
        )
        #expect(resolved?.timeZone == india)
        #expect(resolved?.isGuess == true)
    }

    /// "9:04 PM, same as you" costs a reader attention and tells them nothing.
    @Test func aGuessThatMatchesTheReadersOwnClockIsDropped() {
        // Ireland keeps London's time exactly.
        let resolved = PersonTimeZone.resolve(identifier: nil, number: "+353 1 222 2222", device: london)
        #expect(resolved == nil)
    }

    /// But a choice the user made is an answer to a question they asked, so it
    /// comes back even when it agrees with their own clock.
    @Test func aChosenZoneThatMatchesTheReadersClockIsStillShown() {
        let resolved = PersonTimeZone.resolve(identifier: "Europe/Dublin", number: nil, device: london)
        #expect(resolved?.timeZone == TimeZone(identifier: "Europe/Dublin"))
        #expect(resolved?.isGuess == false)
    }

    @Test func nothingToGoOnResolvesToNothing() {
        #expect(PersonTimeZone.resolve(identifier: nil, number: nil, device: london) == nil)
        #expect(PersonTimeZone.resolve(identifier: nil, number: "020 7946 0018", device: london) == nil)
    }

    // MARK: - Wording

    /// A fixed winter instant, so no zone under test is in daylight saving and
    /// the offsets are the ones these countries are known by.
    private var january: Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 1, day: 15, hour: 12
        ).date!
    }

    @Test func wordsAWholeHourOffset() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        #expect(PersonTimeZone.offsetLabel(for: berlin, device: london, now: january) == "1h ahead")
    }

    @Test func wordsAnOffsetBehind() {
        let newYork = TimeZone(identifier: "America/New_York")!
        #expect(PersonTimeZone.offsetLabel(for: newYork, device: london, now: january) == "5h behind")
    }

    @Test func wordsAHalfHourOffset() {
        #expect(PersonTimeZone.offsetLabel(for: india, device: london, now: january) == "5h 30m ahead")
    }

    @Test func wordsAnOffsetOfMinutesAlone() {
        let kathmandu = TimeZone(identifier: "Asia/Kathmandu")!
        #expect(PersonTimeZone.offsetLabel(for: kathmandu, device: india, now: january) == "15m ahead")
    }

    @Test func wordsNoOffsetAtAll() {
        let dublin = TimeZone(identifier: "Europe/Dublin")!
        #expect(PersonTimeZone.offsetLabel(for: dublin, device: london, now: january) == "same time as you")
    }

    /// VoiceOver reads `3h` as "three h", so the spoken form spells it out.
    @Test func spellsTheOffsetOutForVoiceOver() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        #expect(PersonTimeZone.offsetAccessibilityLabel(for: berlin, device: london, now: january) == "1 hour ahead")
        #expect(PersonTimeZone.offsetAccessibilityLabel(for: india, device: london, now: january) == "5 hours 30 minutes ahead")

        let dublin = TimeZone(identifier: "Europe/Dublin")!
        #expect(PersonTimeZone.offsetAccessibilityLabel(for: dublin, device: london, now: january) == "the same time as you")
    }

    // MARK: - The catalog

    @Test func readsTheCityOutOfAnIdentifier() {
        #expect(TimeZoneCatalog.city(of: "Europe/Berlin") == "Berlin")
        #expect(TimeZoneCatalog.city(of: "America/Port_of_Spain") == "Port of Spain")
        #expect(TimeZoneCatalog.city(of: "America/Argentina/Buenos_Aires") == "Buenos Aires")
    }

    @Test func findsAZoneByCity() {
        let matches = TimeZoneCatalog.groups(matching: "calcutta")
        #expect(matches.flatMap(\.zones).contains { $0.identifier == "Asia/Calcutta" })
    }

    /// The row says a city, but a reader looking for it types the country.
    @Test func findsAZoneByTheNameOfItsTime() {
        let matches = TimeZoneCatalog.groups(matching: "india")
        #expect(matches.flatMap(\.zones).contains { $0.identifier == "Asia/Calcutta" })
    }

    @Test func anEmptySearchKeepsEverything() {
        #expect(TimeZoneCatalog.groups(matching: "   ") == TimeZoneCatalog.all)
        #expect(!TimeZoneCatalog.all.isEmpty)
    }

    @Test func aSearchThatMatchesNothingReturnsNothing() {
        #expect(TimeZoneCatalog.groups(matching: "zzzznowhere").isEmpty)
    }

    /// GMT, UTC, EST and Zulu duplicate real zones under names that mean
    /// nothing to someone looking for a place.
    @Test func leavesOutTheAbbreviationAliases() {
        let identifiers = Set(TimeZoneCatalog.all.flatMap(\.zones).map(\.identifier))
        #expect(!identifiers.contains("GMT"))
        #expect(!identifiers.contains("UTC"))
        #expect(!identifiers.contains("EST"))
    }

    // MARK: - The tables underneath

    @Test func mapsAnInternationalPrefixToItsRegion() {
        #expect(DiallingCodes.region(forInternationalDigits: "918022222222") == "IN")
        #expect(DiallingCodes.region(forInternationalDigits: "442079460018") == "GB")
        #expect(DiallingCodes.region(forInternationalDigits: "12024561111") == "US")
    }

    @Test func refusesAPrefixNoRegionDials() {
        #expect(DiallingCodes.region(forInternationalDigits: "999999999") == nil)
    }

    /// Every region the dialling table knows must either resolve to a real
    /// zone or to nothing — never to an identifier iOS can't build.
    @Test func everyRegionEitherResolvesOrStaysSilent() {
        for region in ["IN", "GB", "DE", "JP", "SG", "US", "AU", "BR", "RU", "CN", "UA", "XK"] {
            if let zone = RegionTimeZones.timeZone(for: region) {
                #expect(TimeZone(identifier: zone.identifier) != nil, "\(region) built an unusable zone")
            }
        }
        #expect(RegionTimeZones.timeZone(for: "gb") == TimeZone(identifier: "Europe/London"))
        #expect(RegionTimeZones.timeZone(for: "ZZ") == nil)
    }

    /// The table is generated from the tz database, which renames zones that
    /// Foundation still lists under their old names. `TimeZone` compares by
    /// identifier string, so a table spelling one `Asia/Kolkata` while the
    /// picker lists `Asia/Calcutta` would give two unequal objects for the same
    /// place: the guess would never match a row, and the checkmark would never
    /// appear. Every identifier must be one Foundation itself lists.
    @Test func zonesAreIdentifiersFoundationKnows() {
        let known = Set(TimeZone.knownTimeZoneIdentifiers)
        for identifier in RegionTimeZones.allIdentifiers {
            #expect(known.contains(identifier), "\(identifier) is not an identifier Foundation lists")
        }
    }

    /// The same trap, from the other side: what the number guesses has to be
    /// selectable in the picker, or a correct guess looks unset.
    @Test func aGuessedZoneIsOneThePickerLists() {
        let guessed = PersonTimeZone.guess(number: "+91 22 2202 1111")
        let listed = Set(TimeZoneCatalog.all.flatMap(\.zones).map(\.identifier))
        #expect(guessed.map { listed.contains($0.identifier) } == true)
    }
}
