import Foundation

/// ISO 3166-1 alpha-2 region → the one timezone everyone there keeps.
///
/// Foundation exposes no country-to-timezone map — `Locale.Region` offers a
/// continent code and nothing more — so the table is carried here for the
/// same reason `DiallingCodes` is. It was generated from the tz database's
/// `zone.tab` (public domain), keeping a region only when every zone it lists
/// holds the same offset as its first across a year of sample points. That
/// collapses historical splits which agree in practice (Europe/Büsingen with
/// Europe/Berlin) while disqualifying real ones (America/New_York against
/// America/Chicago).
///
/// **A region that observes more than one time is absent, not approximated.**
/// A phone number says which country someone is in, never which part of it, so
/// a number in the United States, Canada, Australia, Brazil, Mexico, Russia or
/// Indonesia resolves to nothing and waits to be told. Same reasoning as
/// `PhoneNumberFormatter.e164Digits`: a wrong answer here is worse than none,
/// because nothing on screen would mark it as a guess.
///
/// Identifiers are spelled the way `TimeZone.knownTimeZoneIdentifiers` spells
/// them, which is not always the way `zone.tab` does — Foundation still lists
/// `Asia/Calcutta` for what tzdb now calls `Asia/Kolkata`. `TimeZone` compares
/// by identifier string, so the two names are *unequal objects for the same
/// zone*, and a table using the other spelling would quietly never match the
/// picker. `zonesAreIdentifiersFoundationKnows` in the tests holds that line.
///
/// Regenerate with `swift scripts/generate-region-timezones.swift` when the
/// tz database moves under a new Xcode, and paste the table below. The
/// `overrides` above it are hand-written and survive regeneration.
nonisolated enum RegionTimeZones {
    /// The timezone for a region, or nil when the region keeps more than one.
    static func timeZone(for region: String) -> TimeZone? {
        guard let identifier = table[region.uppercased()] else { return nil }
        return TimeZone(identifier: identifier)
    }

    /// Every identifier the table can return, for the test that checks them.
    static var allIdentifiers: [String] { Array(table.values) }

    /// Exceptions to the generated table, where a country legally keeps one
    /// time but `zone.tab` records a second zone for local practice or for
    /// territory outside that law. Both of these are one legal time.
    private static let overrides: [String: String] = [
        // The whole country runs on Beijing time by law; Asia/Urumqi records
        // the unofficial local reckoning in Xinjiang.
        "CN": "Asia/Shanghai",
        // One legal time nationwide; Europe/Simferopol records occupied
        // territory keeping Moscow's.
        "UA": "Europe/Kyiv",
        // tzdb files Kosovo under Belgrade rather than giving it a zone.
        "XK": "Europe/Belgrade",
    ]

    private static let table: [String: String] = generated.merging(overrides) { _, override in override }

    private static let generated: [String: String] = [
        "AD": "Europe/Andorra", "AE": "Asia/Dubai", "AF": "Asia/Kabul", "AG": "America/Antigua",
        "AI": "America/Anguilla", "AL": "Europe/Tirane", "AM": "Asia/Yerevan", "AO": "Africa/Luanda",
        "AR": "America/Argentina/Buenos_Aires", "AS": "Pacific/Pago_Pago", "AT": "Europe/Vienna", "AW": "America/Aruba",
        "AX": "Europe/Mariehamn", "AZ": "Asia/Baku",
        "BA": "Europe/Sarajevo", "BB": "America/Barbados", "BD": "Asia/Dhaka", "BE": "Europe/Brussels",
        "BF": "Africa/Ouagadougou", "BG": "Europe/Sofia", "BH": "Asia/Bahrain", "BI": "Africa/Bujumbura",
        "BJ": "Africa/Porto-Novo", "BL": "America/St_Barthelemy", "BM": "Atlantic/Bermuda", "BN": "Asia/Brunei",
        "BO": "America/La_Paz", "BQ": "America/Kralendijk", "BS": "America/Nassau", "BT": "Asia/Thimphu",
        "BW": "Africa/Gaborone", "BY": "Europe/Minsk", "BZ": "America/Belize",
        "CC": "Indian/Cocos", "CF": "Africa/Bangui", "CG": "Africa/Brazzaville", "CH": "Europe/Zurich",
        "CI": "Africa/Abidjan", "CK": "Pacific/Rarotonga", "CM": "Africa/Douala", "CO": "America/Bogota",
        "CR": "America/Costa_Rica", "CU": "America/Havana", "CV": "Atlantic/Cape_Verde", "CW": "America/Curacao",
        "CX": "Indian/Christmas", "CY": "Asia/Nicosia", "CZ": "Europe/Prague",
        "DE": "Europe/Berlin", "DJ": "Africa/Djibouti", "DK": "Europe/Copenhagen", "DM": "America/Dominica",
        "DO": "America/Santo_Domingo", "DZ": "Africa/Algiers",
        "EE": "Europe/Tallinn", "EG": "Africa/Cairo", "EH": "Africa/El_Aaiun", "ER": "Africa/Asmara",
        "ET": "Africa/Addis_Ababa",
        "FI": "Europe/Helsinki", "FJ": "Pacific/Fiji", "FK": "Atlantic/Stanley", "FO": "Atlantic/Faroe",
        "FR": "Europe/Paris",
        "GA": "Africa/Libreville", "GB": "Europe/London", "GD": "America/Grenada", "GE": "Asia/Tbilisi",
        "GF": "America/Cayenne", "GG": "Europe/Guernsey", "GH": "Africa/Accra", "GI": "Europe/Gibraltar",
        "GM": "Africa/Banjul", "GN": "Africa/Conakry", "GP": "America/Guadeloupe", "GQ": "Africa/Malabo",
        "GR": "Europe/Athens", "GS": "Atlantic/South_Georgia", "GT": "America/Guatemala", "GU": "Pacific/Guam",
        "GW": "Africa/Bissau", "GY": "America/Guyana",
        "HK": "Asia/Hong_Kong", "HN": "America/Tegucigalpa", "HR": "Europe/Zagreb", "HT": "America/Port-au-Prince",
        "HU": "Europe/Budapest",
        "IE": "Europe/Dublin", "IL": "Asia/Jerusalem", "IM": "Europe/Isle_of_Man", "IN": "Asia/Calcutta",
        "IO": "Indian/Chagos", "IQ": "Asia/Baghdad", "IR": "Asia/Tehran", "IS": "Atlantic/Reykjavik",
        "IT": "Europe/Rome",
        "JE": "Europe/Jersey", "JM": "America/Jamaica", "JO": "Asia/Amman", "JP": "Asia/Tokyo",
        "KE": "Africa/Nairobi", "KG": "Asia/Bishkek", "KH": "Asia/Phnom_Penh", "KM": "Indian/Comoro",
        "KN": "America/St_Kitts", "KP": "Asia/Pyongyang", "KR": "Asia/Seoul", "KW": "Asia/Kuwait",
        "KY": "America/Cayman", "KZ": "Asia/Almaty",
        "LA": "Asia/Vientiane", "LB": "Asia/Beirut", "LC": "America/St_Lucia", "LI": "Europe/Vaduz",
        "LK": "Asia/Colombo", "LR": "Africa/Monrovia", "LS": "Africa/Maseru", "LT": "Europe/Vilnius",
        "LU": "Europe/Luxembourg", "LV": "Europe/Riga", "LY": "Africa/Tripoli",
        "MA": "Africa/Casablanca", "MC": "Europe/Monaco", "MD": "Europe/Chisinau", "ME": "Europe/Podgorica",
        "MF": "America/Marigot", "MG": "Indian/Antananarivo", "MH": "Pacific/Majuro", "MK": "Europe/Skopje",
        "ML": "Africa/Bamako", "MM": "Asia/Yangon", "MO": "Asia/Macau", "MP": "Pacific/Saipan",
        "MQ": "America/Martinique", "MR": "Africa/Nouakchott", "MS": "America/Montserrat", "MT": "Europe/Malta",
        "MU": "Indian/Mauritius", "MV": "Indian/Maldives", "MW": "Africa/Blantyre", "MY": "Asia/Kuala_Lumpur",
        "MZ": "Africa/Maputo",
        "NA": "Africa/Windhoek", "NC": "Pacific/Noumea", "NE": "Africa/Niamey", "NF": "Pacific/Norfolk",
        "NG": "Africa/Lagos", "NI": "America/Managua", "NL": "Europe/Amsterdam", "NO": "Europe/Oslo",
        "NP": "Asia/Kathmandu", "NR": "Pacific/Nauru", "NU": "Pacific/Niue",
        "OM": "Asia/Muscat",
        "PA": "America/Panama", "PE": "America/Lima", "PH": "Asia/Manila", "PK": "Asia/Karachi",
        "PL": "Europe/Warsaw", "PM": "America/Miquelon", "PN": "Pacific/Pitcairn", "PR": "America/Puerto_Rico",
        "PS": "Asia/Gaza", "PW": "Pacific/Palau", "PY": "America/Asuncion",
        "QA": "Asia/Qatar",
        "RE": "Indian/Reunion", "RO": "Europe/Bucharest", "RS": "Europe/Belgrade", "RW": "Africa/Kigali",
        "SA": "Asia/Riyadh", "SB": "Pacific/Guadalcanal", "SC": "Indian/Mahe", "SD": "Africa/Khartoum",
        "SE": "Europe/Stockholm", "SG": "Asia/Singapore", "SH": "Atlantic/St_Helena", "SI": "Europe/Ljubljana",
        "SJ": "Arctic/Longyearbyen", "SK": "Europe/Bratislava", "SL": "Africa/Freetown", "SM": "Europe/San_Marino",
        "SN": "Africa/Dakar", "SO": "Africa/Mogadishu", "SR": "America/Paramaribo", "SS": "Africa/Juba",
        "ST": "Africa/Sao_Tome", "SV": "America/El_Salvador", "SX": "America/Lower_Princes", "SY": "Asia/Damascus",
        "SZ": "Africa/Mbabane",
        "TC": "America/Grand_Turk", "TD": "Africa/Ndjamena", "TF": "Indian/Kerguelen", "TG": "Africa/Lome",
        "TH": "Asia/Bangkok", "TJ": "Asia/Dushanbe", "TK": "Pacific/Fakaofo", "TL": "Asia/Dili",
        "TM": "Asia/Ashgabat", "TN": "Africa/Tunis", "TO": "Pacific/Tongatapu", "TR": "Europe/Istanbul",
        "TT": "America/Port_of_Spain", "TV": "Pacific/Funafuti", "TW": "Asia/Taipei", "TZ": "Africa/Dar_es_Salaam",
        "UG": "Africa/Kampala", "UY": "America/Montevideo", "UZ": "Asia/Samarkand",
        "VA": "Europe/Vatican", "VC": "America/St_Vincent", "VE": "America/Caracas", "VG": "America/Tortola",
        "VI": "America/St_Thomas", "VN": "Asia/Ho_Chi_Minh", "VU": "Pacific/Efate",
        "WF": "Pacific/Wallis", "WS": "Pacific/Apia",
        "YE": "Asia/Aden", "YT": "Indian/Mayotte",
        "ZA": "Africa/Johannesburg", "ZM": "Africa/Lusaka", "ZW": "Africa/Harare",
    ]
}
