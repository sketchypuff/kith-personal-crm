import SwiftData
import SwiftUI

/// The `TabView` shell. One `NavigationStack` per tab; Today is the default.
struct RootTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max", value: .today) {
                TodayView()   // owns its own NavigationStack (needs the path for the duplicate-guard push)
            }
            Tab("People", systemImage: "person.2", value: .people) {
                PeopleView()   // owns its own NavigationStack, same reason as Today
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.previewContainer())
        .environment(ContactImageCache())
}
