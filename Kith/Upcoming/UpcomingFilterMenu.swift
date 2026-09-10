import SwiftUI

/// The nav-bar horizon filter: how far ahead the feed looks.
/// The icon fills whenever the window is narrowed, matching the People
/// roster's filter, so a narrowed feed is never silently narrow.
struct UpcomingFilterMenu: View {
    @Binding var horizon: UpcomingHorizon

    var body: some View {
        Menu("Filter", systemImage: iconName) {
            Picker("Show", selection: $horizon) {
                ForEach(UpcomingHorizon.allCases) { horizon in
                    Text(horizon.label).tag(horizon)
                }
            }
            .pickerStyle(.inline)
        }
        .accessibilityValue(horizon.label)
    }

    private var iconName: String {
        horizon == .default ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
    }
}
