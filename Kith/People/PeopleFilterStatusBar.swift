import SwiftUI

/// The inline "Overdue · tag: clients" line shown above the list while a filter is on.
struct PeopleFilterStatusBar: View {
    let summary: String
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear", action: onClear)
                .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
