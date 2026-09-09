import SwiftData
import SwiftUI

@main
struct KithApp: App {
    @State private var coordinator = ModelContainerCoordinator()
    @State private var contactImages = ContactImageCache()

    var body: some Scene {
        WindowGroup {
            AppLockGate()   // wraps RootTabView; nothing renders behind the privacy lock
                .environment(coordinator)
                .environment(contactImages)
                .modelContainer(coordinator.container)
                .task(id: ObjectIdentifier(coordinator.container)) {
                    SampleData.seedIfRequested(into: coordinator.container.mainContext)
                }
        }
    }
}
