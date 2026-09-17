import SwiftData
import SwiftUI

/// The `TabView` shell. One `NavigationStack` per tab; Upcoming is the default.
struct RootTabView: View {
    @State private var selectedTab: AppTab = .upcoming

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Upcoming", systemImage: "calendar", value: .upcoming) {
                UpcomingView()   // owns its own NavigationStack (needs the path for the duplicate-guard push)
            }
            Tab("People", systemImage: "person.2", value: .people) {
                PeopleView()   // owns its own NavigationStack, same reason as Upcoming
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
        .environment(ContactPhoneCache())
        .environment(NotificationConsent())
}
