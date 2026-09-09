import Foundation

/// One social row on the developer card. Opened externally by the system;
/// no Kith data is attached (Settings §8.2, §11.3).
struct DeveloperLink: Identifiable {
    let network: String
    let systemImage: String
    let urlString: String

    var id: String { network }

    var url: URL? {
        URL(string: urlString)
    }
}
