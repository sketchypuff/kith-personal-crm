import Contacts
import UIKit

/// Shared cache of contact thumbnails keyed by `linkedContactID`.
/// Reads happen off the main thread; the monogram is the placeholder.
@Observable
final class ContactImageCache {
    private var images: [String: UIImage] = [:]
    private var misses: Set<String> = []

    func cached(_ contactID: String) -> UIImage? {
        images[contactID]
    }

    /// Returns the cached image or fetches it once, asking for Contacts access
    /// the first time a linked card is read.
    func image(for contactID: String) async -> UIImage? {
        guard !contactID.isEmpty else { return nil }
        if let image = images[contactID] { return image }
        if misses.contains(contactID) { return nil }

        guard await ContactAccess.ensureGranted() else { return nil }

        let data = await Self.fetchThumbnailData(contactID: contactID)
        if let data, let image = UIImage(data: data) {
            images[contactID] = image
            return image
        }
        misses.insert(contactID)
        return nil
    }

    private nonisolated static func fetchThumbnailData(contactID: String) async -> Data? {
        let store = CNContactStore()
        let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor]
        return try? store.unifiedContact(withIdentifier: contactID, keysToFetch: keys).thumbnailImageData
    }
}
