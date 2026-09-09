import Foundation

/// The developer card's content (Settings §8.2). The avatar is the bundled
/// `DeveloperAvatar` image set — never a network fetch — so the card renders
/// identically offline.
enum DeveloperProfile {
    static let name = "Yash Shenai"
    static let avatarAssetName = "DeveloperAvatar"

    static let bio = "He is a product designer working on agentic Copilot experiences on MS Office products at Microsoft. His girlfriend wanted an app to help her sustain her network, hence this. Ah, the things we do for love!"

    static let links: [DeveloperLink] = [
        DeveloperLink(network: "X", systemImage: "at", urlString: "https://x.com/yashshenai"),
        DeveloperLink(network: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right", urlString: "https://github.com/sketchypuff"),
        DeveloperLink(network: "LinkedIn", systemImage: "briefcase", urlString: "https://www.linkedin.com/in/yashshenai/"),
    ]
}
