import SwiftUI

/// The quiet Contacts-style tally at the end of the list: "128 people", or
/// "4 people · Overdue · tag: clients" under a filter. Grammar agreement is
/// handled by `Text`'s `^[…](inflect: true)` markup.
struct PeopleCountFooter: View {
    let count: Int
    let filterSummary: String?

    var body: some View {
        Group {
            if let filterSummary {
                Text("^[\(count) person](inflect: true) · \(filterSummary)")
            } else {
                Text("^[\(count) person](inflect: true)")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        Section {
        } footer: {
            PeopleCountFooter(count: 1, filterSummary: nil)
        }
        Section {
        } footer: {
            PeopleCountFooter(count: 4, filterSummary: "Overdue · tag: clients")
        }
    }
    .listStyle(.plain)
}
