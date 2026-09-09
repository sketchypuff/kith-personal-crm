import Foundation

/// Kith's App Store listing. The "Review in App Store" row only appears once
/// `appID` is filled in, so the row can ship before the listing exists.
enum AppStoreListing {
    /// PLACEHOLDER — the numeric Apple ID from App Store Connect (the digits
    /// after `id` in the listing URL). Leave empty until Kith is live.
    static let appID = ""

    static var isAvailable: Bool {
        !appID.isEmpty
    }

    /// Deep link straight to the write-a-review sheet in the App Store app.
    static var writeReviewURL: URL? {
        guard isAvailable else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }
}
