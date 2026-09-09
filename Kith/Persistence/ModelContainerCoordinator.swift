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

    /// Whether the live container mirrors to CloudKit. This is the *actual*
    /// state: it lags the preference when CloudKit was unavailable at launch
    /// and the coordinator fell back to a local-only container.
    private(set) var syncEnabled: Bool

    private let storeURL: URL?
    private let logger = Logger(subsystem: "com.yash.kith", category: "persistence")

    /// - Parameter storeURL: the on-disk store. Defaults to the App Group store
    ///   shared with the widget; tests pass a temporary file.
    init(syncEnabled: Bool = AppPreferences.syncEnabled, storeURL: URL? = ModelContainerCoordinator.appGroupStoreURL) {
        self.storeURL = storeURL

        if syncEnabled {
            if let synced = try? Self.makeContainer(syncEnabled: true, storeURL: storeURL) {
                container = synced
                self.syncEnabled = true
                return
            }
            Logger(subsystem: "com.yash.kith", category: "persistence")
                .error("CloudKit container failed to initialize; falling back to local store.")
        }

        do {
            container = try Self.makeContainer(syncEnabled: false, storeURL: storeURL)
            self.syncEnabled = false
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }

    /// True when a usable iCloud account is signed in on this device.
    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Called by the Settings sync toggle. Opens the *same* on-disk store with
    /// the other `cloudKitDatabase` value; no data is copied, and turning sync
    /// off leaves the iCloud copy intact (Settings §7.3).
    ///
    /// Returns false — with the previous container still in place — when the
    /// store can't be reopened as requested, so the caller can roll the
    /// preference back rather than half-apply (Settings §7.2).
    @discardableResult
    func rebuild(syncEnabled requested: Bool) -> Bool {
        do {
            container = try Self.makeContainer(syncEnabled: requested, storeURL: storeURL)
            syncEnabled = requested
            return true
        } catch {
            logger.error("Container rebuild with sync \(requested) failed: \(error.localizedDescription)")
            return false
        }
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

    private static func makeContainer(syncEnabled: Bool, storeURL: URL?) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = syncEnabled ? .private(cloudKitContainerID) : .none
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: database)
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: database)
        }
        return try ModelContainer(for: schema, configurations: configuration)
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
