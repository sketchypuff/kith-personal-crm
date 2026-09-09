import SwiftUI

/// The nav-bar filter menu (People §7): Overdue toggle + single-tag picker.
/// The icon fills whenever a filter is active so it's never invisible.
struct PeopleFilterMenu: View {
    @Binding var filter: RosterFilter
    let tags: [String]

    var body: some View {
        Menu("Filter", systemImage: iconName) {
            Toggle("Overdue only", isOn: $filter.overdueOnly)

            if !tags.isEmpty {
                Picker("Tag", selection: $filter.tag) {
                    Text("All tags").tag(String?.none)
                    ForEach(tags, id: \.self) { tag in
                        Text(tag).tag(Optional(tag))
                    }
                }
                .pickerStyle(.inline)
            }

            if filter.isActive {
                Button("Clear filters", systemImage: "xmark.circle", action: clear)
            }
        }
        .accessibilityValue(filter.summary ?? "None")
    }

    private var iconName: String {
        filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private func clear() {
        filter.clear()
    }
}
