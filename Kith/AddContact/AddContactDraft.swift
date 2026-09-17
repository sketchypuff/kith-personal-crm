import Foundation

struct AddContactDraft {
    var name: String
    var cadence: Cadence
    var notifyDay: Weekday
    var notifyTime: Date
    var tags: [String]
    var birthday: DateComponents?
}
