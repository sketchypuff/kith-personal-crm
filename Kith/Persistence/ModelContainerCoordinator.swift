import Foundation
import OSLog
import SwiftData

/// Owns the app's `ModelContainer` and republishes it into the environment.
///
/// Sync on/off is a *different* `ModelConfiguration` (`.private(...)` vs
/// `.none`), so toggling it rebuilds the container rather than flipping a flag.
@Observable
final class ModelContainerCoordinator {
    static let schema = Schema([Person.self, Touch.self, SkipMarker.self, KeyDate.self])
    static let cloudKitContainerID = "iCloud.com.yash.kith"

    private(set) var container: ModelContainer
    private(set) var syncEnabled: Bool

    private let logger = Logger(subsystem: "com.yash.kith", category: "persistence")

    init(syncEnabled: Bool = AppPreferences.syncEnabled) {
        self.syncEnabled = syncEnabled
        self.container = Self.makeContainer(syncEnabled: syncEnabled)
    }

    /// Called by the Settings sync toggle. Turning sync off leaves the iCloud copy intact.
    func rebuild(syncEnabled: Bool) {
        self.syncEnabled = syncEnabled
        container = Self.makeContainer(syncEnabled: syncEnabled)
    }

    /// The store file inside the App Group container, shared with the widget.
    /// Resolved through `FileManager` (nil when the process lacks the
    /// entitlement) rather than `groupContainer: .identifier`, which traps
    /// instead of throwing when the entitlement is missing.
    static var appGroupStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppPreferences.suiteName)?
            .appending(path: "Kith.store")
    }

    private static func makeContainer(syncEnabled: Bool) -> ModelContainer {
        let logger = Logger(subsystem: "com.yash.kith", category: "persistence")

        if syncEnabled {
            let synced = configuration(cloudKitDatabase: .private(cloudKitContainerID))
            if let container = try? ModelContainer(for: schema, configurations: synced) {
                return container
            }
            logger.error("CloudKit container failed to initialize; falling back to local store.")
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration(cloudKitDatabase: .none))
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }

    private static func configuration(cloudKitDatabase: ModelConfiguration.CloudKitDatabase) -> ModelConfiguration {
        if let url = appGroupStoreURL {
            return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloudKitDatabase)
        }
        return ModelConfiguration(schema: schema, cloudKitDatabase: cloudKitDatabase)
    }

    /// An in-memory container for previews and tests.
    static func inMemory() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create the in-memory container: \(error)")
        }
    }
}
