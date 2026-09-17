import Foundation

/// Every timezone iOS knows, arranged for a list and searchable by the words
/// someone would actually type.
///
/// The tz database names a zone after a city (`Asia/Kolkata`), which is what
/// the row shows, but a reader looking for it is as likely to type "India" or
/// "IST". Search therefore covers the city, the region it sits under, and the
/// localized name of the zone itself.
nonisolated enum TimeZoneCatalog {
    struct Zone: Equatable {
        let identifier: String
        let city: String
        let offset: String
        /// Lowercased haystack, built once at load rather than per keystroke.
        let searchText: String
    }

    struct Group: Equatable {
        let name: String
        let zones: [Zone]
    }

    /// The city a tz identifier is named for, with its underscores read as the
    /// spaces they stand in for: `America/Port_of_Spain` → `Port of Spain`.
    static func city(of identifier: String) -> String {
        let tail = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return tail.replacingOccurrences(of: "_", with: " ")
    }

    /// Groups whose zones match, with non-matching zones dropped. An empty
    /// search returns everything.
    static func groups(matching search: String) -> [Group] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return all }
        return all.compactMap { group in
            let matches = group.zones.filter { $0.searchText.contains(needle) }
            return matches.isEmpty ? nil : Group(name: group.name, zones: matches)
        }
    }

    static let all: [Group] = build()

    private static func build() -> [Group] {
        var byRegion: [String: [Zone]] = [:]

        for identifier in TimeZone.knownTimeZoneIdentifiers {
            // Zones with no `/` are the tz database's aliases and abbreviations
            // — GMT, UTC, EST, Zulu. They duplicate real zones under names that
            // mean nothing to a reader looking for a place.
            guard let slash = identifier.firstIndex(of: "/"),
                  let zone = TimeZone(identifier: identifier) else { continue }

            let region = String(identifier[..<slash]).replacingOccurrences(of: "_", with: " ")
            let city = city(of: identifier)
            let localized = zone.localizedName(for: .generic, locale: .current) ?? ""
            let abbreviation = zone.abbreviation() ?? ""

            byRegion[region, default: []].append(
                Zone(
                    identifier: identifier,
                    city: city,
                    offset: offsetLabel(for: zone),
                    searchText: "\(city) \(region) \(localized) \(abbreviation) \(identifier)".lowercased()
                )
            )
        }

        return byRegion.keys.sorted().map { region in
            Group(
                name: region,
                zones: byRegion[region, default: []]
                    .sorted { $0.city.localizedStandardCompare($1.city) == .orderedAscending }
            )
        }
    }

    /// `GMT+5:30`, matching how iOS writes an offset elsewhere.
    private static func offsetLabel(for zone: TimeZone) -> String {
        let seconds = zone.secondsFromGMT()
        guard seconds != 0 else { return "GMT" }
        let sign = seconds > 0 ? "+" : "−"
        let total = abs(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        return minutes == 0
            ? "GMT\(sign)\(hours)"
            : String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}
