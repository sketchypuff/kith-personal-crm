import Foundation

extension Bundle {
    /// The marketing version ("1.0") for the About section. The build number
    /// stays in the bundle for TestFlight but isn't shown.
    var versionDescription: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
