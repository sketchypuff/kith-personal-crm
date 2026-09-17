import SwiftData
import SwiftUI

@main
struct KithApp: App {
    @State private var coordinator = ModelContainerCoordinator()
    @State private var contactImages = ContactImageCache()
    @State private var contactPhones = ContactPhoneCache()

    /// Settings › Other › Theme. Applied here so every scene, including the
    /// lock screen and sheets, follows it.
    @AppStorage(AppPreferences.Key.appTheme, store: AppPreferences.store)
    private var theme: AppTheme = .system

    /// Seed the appearance proxies before the first bar is built; the root
    /// modifier keeps them current from then on.
    init() {
        RoundedChrome.apply()
    }

    var body: some Scene {
        WindowGroup {
            AppLockGate()   // wraps RootTabView; nothing renders behind the privacy lock
                .roundedTypeface()   // SF Rounded everywhere, SwiftUI text and UIKit chrome alike
                .environment(coordinator)
                .environment(contactImages)
                .environment(contactPhones)
                .modelContainer(coordinator.container)
                .preferredColorScheme(theme.colorScheme)
                .task(id: ObjectIdentifier(coordinator.container)) {
                    SampleData.seedIfRequested(into: coordinator.container.mainContext)
                    // After the sample seed, so a freshly seeded roster's tags
                    // land in the vocabulary too.
                    TagActions(context: coordinator.container.mainContext).seedIfNeeded()
                }
        }
    }
}
