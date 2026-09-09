import SwiftUI

/// Light / Dark / System. A plain value write; `KithApp` reads the same key
/// and applies it as the preferred color scheme.
struct ThemeRow: View {
    @AppStorage(AppPreferences.Key.appTheme, store: AppPreferences.store)
    private var theme: AppTheme = .system

    var body: some View {
        Picker("Theme", selection: $theme) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Text(theme.label).tag(theme)
            }
        }
        .pickerStyle(.menu)
    }
}
