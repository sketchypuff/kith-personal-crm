import SwiftUI
import UIKit

/// SF Rounded for the chrome `.fontDesign(.rounded)` cannot reach.
///
/// The app sets its typeface once, on the root view in `KithApp`. That covers
/// every SwiftUI `Text`, but navigation bar titles, tab bar labels, and the
/// segmented control are UIKit-drawn and read their fonts from appearance
/// proxies instead of the SwiftUI environment.
///
/// Only the font *design* is overridden: every size and weight here is the one
/// UIKit would have used anyway. Fonts are resolved at the current Dynamic
/// Type size and baked into the proxies, so `apply()` runs again on every
/// Dynamic Type change — and because a proxy only seeds controls built after
/// it, the pass ends by pushing the same fonts onto whatever is already on
/// screen.
enum RoundedChrome {
    static func apply() {
        applyToNavigationBars()
        applyToTabBars()
        applyToSegmentedControls()
        refreshVisibleChrome()
    }

    // MARK: - The fonts

    /// Always resolved fresh rather than read back from the proxy: the proxy
    /// holds the font from the *last* pass, which is the wrong size once
    /// Dynamic Type has moved.
    private static var inlineTitleFont: UIFont {
        rounded(.preferredFont(forTextStyle: .headline))
    }

    private static var largeTitleFont: UIFont {
        rounded(.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, weight: .bold))
    }

    /// The selected segment is drawn semibold, so each state gets its own
    /// weight — one shared regular font would flatten the selection.
    private static let segmentStates: [(state: UIControl.State, weight: UIFont.Weight)] = [
        (.normal, .regular),
        (.selected, .semibold),
        (.highlighted, .semibold),
    ]

    private static func segmentFont(_ weight: UIFont.Weight) -> UIFont {
        rounded(.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: weight))
    }

    // MARK: - Proxies

    private static func applyToNavigationBars() {
        let proxy = UINavigationBar.appearance()
        proxy.titleTextAttributes = setting(inlineTitleFont, in: proxy.titleTextAttributes)
        proxy.largeTitleTextAttributes = setting(largeTitleFont, in: proxy.largeTitleTextAttributes)
    }

    /// The tab bar ignores the legacy `UITabBarItem` proxy, so it takes an
    /// appearance object instead. The template comes from a throwaway bar
    /// rather than from a fresh `UITabBarAppearance`: that is UIKit's real
    /// default for this OS at the current type size, so each label keeps its
    /// own size and weight and only the design changes.
    private static func applyToTabBars() {
        UITabBar.appearance().standardAppearance = roundedTabBarAppearance()
    }

    private static func roundedTabBarAppearance() -> UITabBarAppearance {
        let appearance = UITabBar().standardAppearance
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]
        for layout in layouts {
            for item in [layout.normal, layout.selected, layout.focused, layout.disabled] {
                let base = item.titleTextAttributes[.font] as? UIFont ?? .preferredFont(forTextStyle: .caption2)
                item.titleTextAttributes = setting(rounded(base), in: item.titleTextAttributes)
            }
        }
        return appearance
    }

    private static func applyToSegmentedControls() {
        let proxy = UISegmentedControl.appearance()
        for (state, weight) in segmentStates {
            proxy.setTitleTextAttributes(
                setting(segmentFont(weight), in: proxy.titleTextAttributes(for: state)),
                for: state
            )
        }
    }

    // MARK: - Chrome already on screen

    /// A proxy only seeds controls created after it is set, so without this a
    /// Dynamic Type change would leave every visible title at the old size
    /// until the app relaunched.
    private static func refreshVisibleChrome() {
        let roots = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for root in roots {
            for view in descendants(of: root) {
                switch view {
                case let bar as UINavigationBar:
                    bar.titleTextAttributes = setting(inlineTitleFont, in: bar.titleTextAttributes)
                    bar.largeTitleTextAttributes = setting(largeTitleFont, in: bar.largeTitleTextAttributes)
                case let bar as UITabBar:
                    bar.standardAppearance = roundedTabBarAppearance()
                case let control as UISegmentedControl:
                    for (state, weight) in segmentStates {
                        control.setTitleTextAttributes(
                            setting(segmentFont(weight), in: control.titleTextAttributes(for: state)),
                            for: state
                        )
                    }
                default:
                    break
                }
            }
        }
    }

    private static func descendants(of view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }

    // MARK: - Helpers

    /// Replaces the font, leaving any colour or other attributes in place.
    private static func setting(
        _ font: UIFont,
        in attributes: [NSAttributedString.Key: Any]?
    ) -> [NSAttributedString.Key: Any] {
        var attributes = attributes ?? [:]
        attributes[.font] = font
        return attributes
    }

    private static func rounded(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

extension View {
    /// The app's one typeface decision, applied at the root: SF Rounded for
    /// SwiftUI text, and the same design pushed into the UIKit-drawn chrome.
    func roundedTypeface() -> some View {
        modifier(RoundedTypefaceModifier())
    }
}

private struct RoundedTypefaceModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .fontDesign(.rounded)
            .onChange(of: dynamicTypeSize) {
                RoundedChrome.apply()
            }
    }
}
