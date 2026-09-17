import SwiftUI

/// Correcting the guess. Reached from the Notify section, and only ever needed
/// when the number couldn't place someone — a number saved without a country
/// code, or a country that keeps more than one time.
///
/// Stock `List` and `.searchable`, grouped the way the tz database groups
/// itself. Picking a row writes it and leaves; Automatic clears it back to the
/// guess.
struct TimeZonePickerView: View {
    @Binding var identifier: String?
    /// What Automatic works out to right now, so the row can say so instead of
    /// leaving the reader to find out by choosing it.
    let guess: TimeZone?

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        let groups = TimeZoneCatalog.groups(matching: search)

        List {
            Section {
                Button {
                    select(nil)
                } label: {
                    row(title: "Automatic", detail: automaticDetail, isSelected: identifier == nil)
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Worked out from their phone number. A number saved without a country code, or a country that keeps more than one time, can't be placed.")
            }

            ForEach(groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.zones, id: \.identifier) { zone in
                        Button {
                            select(zone.identifier)
                        } label: {
                            row(
                                title: zone.city,
                                detail: zone.offset,
                                isSelected: identifier == zone.identifier
                            )
                        }
                        // Without this the row reads as one long tinted link.
                        // The checkmark carries the tint instead.
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search timezones")
        .navigationTitle("Timezone")
        .toolbarTitleDisplayMode(.inline)
        .overlay {
            if groups.isEmpty && !search.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    private var automaticDetail: String {
        guard let guess else { return "Couldn't place them" }
        return TimeZoneCatalog.city(of: guess.identifier)
    }

    @ViewBuilder
    private func row(title: String, detail: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(detail)
                .foregroundStyle(.secondary)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .font(.body.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func select(_ newValue: String?) {
        identifier = newValue
        dismiss()
    }
}
