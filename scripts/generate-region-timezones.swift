import Foundation
import CryptoKit

// Read zone.tab (public domain, tz database) and emit region -> single zone.
// A region qualifies only when every zone it lists keeps the same offset as
// its first zone at every sample point across the coming year, so historical
// splits that agree today (Europe/Busingen vs Europe/Berlin) collapse, while
// genuine splits (America/New_York vs America/Chicago) disqualify the region.
//
// Names are normalised to whatever TimeZone.knownTimeZoneIdentifiers lists:
// zone.tab carries current tzdb names while Foundation still lists some legacy
// aliases (Asia/Kolkata vs Asia/Calcutta), and TimeZone compares by identifier
// string, so the two names are unequal objects for the same zone. An alias is
// matched to its known name by identical compiled zone data, which is exact.

let known = Set(TimeZone.knownTimeZoneIdentifiers)

func zoneHash(_ id: String) -> String? {
    guard let data = FileManager.default.contents(atPath: "/usr/share/zoneinfo/" + id) else { return nil }
    return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
}

let knownByHash: [String: String] = known.reduce(into: [:]) { map, id in
    if let h = zoneHash(id), map[h] == nil || id < map[h]! { map[h] = id }
}

func normalise(_ id: String) -> String? {
    if known.contains(id) { return id }
    guard let h = zoneHash(id), let match = knownByHash[h] else { return nil }
    FileHandle.standardError.write("// note: \(id) -> \(match)\n".data(using: .utf8)!)
    return match
}

let text = try String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)

var order: [String] = []
var zonesByRegion: [String: [String]] = [:]

for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
    guard !line.hasPrefix("#") else { continue }
    let fields = line.split(separator: "\t")
    guard fields.count >= 3 else { continue }
    let region = String(fields[0])
    let zone = String(fields[2])
    if zonesByRegion[region] == nil {
        zonesByRegion[region] = []
        order.append(region)
    }
    zonesByRegion[region]?.append(zone)
}

// Two samples a month for a year: enough to catch a DST rule that differs
// (Brisbane vs Sydney) as well as a plain offset difference.
let now = Date()
let samples: [Date] = (0..<26).map { now.addingTimeInterval(Double($0) * 14 * 86_400) }

func agrees(_ a: TimeZone, _ b: TimeZone) -> Bool {
    samples.allSatisfy { a.secondsFromGMT(for: $0) == b.secondsFromGMT(for: $0) }
}

var single: [String: String] = [:]
var multi: [String] = []

for region in order {
    guard let zones = zonesByRegion[region], let first = zones.first,
          let canonical = normalise(first),
          let primary = TimeZone(identifier: canonical) else { continue }
    let uniform = zones.allSatisfy { id in
        guard let known = normalise(id), let tz = TimeZone(identifier: known) else { return false }
        return agrees(primary, tz)
    }
    if uniform { single[region] = canonical } else { multi.append(region) }
}

print("// single: \(single.count), multi: \(multi.count)")
print("// multi-zone (resolve to nil): \(multi.sorted().joined(separator: " "))")
print("")

// Emit grouped by first letter, six pairs a line, matching DiallingCodes.
let keys = single.keys.sorted()
var currentLetter: Character = " "
var line: [String] = []
func flush() {
    if !line.isEmpty { print("        " + line.joined(separator: " ")); line = [] }
}
for key in keys {
    let letter = key.first!
    if letter != currentLetter { flush(); currentLetter = letter }
    line.append("\"\(key)\": \"\(single[key]!)\",")
    if line.count == 4 { flush() }
}
flush()
