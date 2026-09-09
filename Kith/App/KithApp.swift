import SwiftData
import SwiftUI

@main
struct KithApp: App {
    @State private var coordinator = ModelContainerCoordinator()
    @State private var contactImages = ContactImageCache()

    /// Settings › Other › Theme. Applied here so every scene, including the
    /// lock screen and sheets, follows it.
    @AppStorage(AppPreferences.Key.appTheme, store: AppPreferences.store)
    private var theme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            AppLockGate()   // wraps RootTabView; nothing renders behind the privacy lock
                .environment(coordinator)
                .environment(contactImages)
                .modelContainer(coordinator.container)
                .preferredColorScheme(theme.colorScheme)
                .task(id: ObjectIdentifier(coordinator.container)) {
                    SampleData.seedIfRequested(into: coordinator.container.mainContext)
                }
        }
    }
}
