import Testing
import UIKit
@testable import Kith

struct OnboardingAssetTests {
    @Test(arguments: ["OnboardingPeople", "OnboardingRhythm", "OnboardingPrivacy"])
    func bundledArtworkHasDistinctLightAndDarkVariants(name: String) throws {
        let lightTraits = UITraitCollection {
            $0.userInterfaceStyle = .light
            $0.displayScale = 3
        }
        let darkTraits = UITraitCollection {
            $0.userInterfaceStyle = .dark
            $0.displayScale = 3
        }
        let light = try #require(UIImage(named: name, in: .main, compatibleWith: lightTraits))
        let dark = try #require(UIImage(named: name, in: .main, compatibleWith: darkTraits))
        for image in [light, dark] {
            let pixels = try #require(image.cgImage)
            #expect(pixels.width == 1536)
            #expect(pixels.height == 1152)
            #expect(image.scale == 3)
            #expect([.first, .last, .premultipliedFirst, .premultipliedLast].contains(pixels.alphaInfo))
        }
        #expect(try #require(light.pngData()) != #require(dark.pngData()))
    }

    @Test func eachIntroductionPageUsesTheMatchingArtwork() {
        #expect(OnboardingPage.allCases.map(\.assetName) == [
            "OnboardingPeople", "OnboardingRhythm", "OnboardingPrivacy"
        ])
    }
}
