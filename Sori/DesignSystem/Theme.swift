import SwiftUI

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Colours

extension Color {
    static let soriBackground = adaptive(light: 0xFAF8F4, dark: 0x111110)
    static let soriSurface = adaptive(light: 0xFFFFFF, dark: 0x1A1A19)
    static let soriSurfaceElevated = adaptive(light: 0xF2EEE7, dark: 0x232321)
    static let soriInk = adaptive(light: 0x1C1B1A, dark: 0xF2EFE9)
    static let soriSecondary = adaptive(light: 0x6B6660, dark: 0xA8A29A)
    static let soriTertiary = adaptive(light: 0x9B948A, dark: 0x7A756D)
    static let soriBorder = adaptive(light: 0xE6E0D6, dark: 0x33312D)
    static let soriAccent = Color.accentColor
    static let soriCorrect = adaptive(light: 0x2F7D4F, dark: 0x6FD39A)
    static let soriError = adaptive(light: 0xB3261E, dark: 0xFF8A80)
    static let soriWarning = adaptive(light: 0xA15C00, dark: 0xFFB74D)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Typography

enum SoriFont {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 26, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let callout = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionStrong = Font.system(size: 13, weight: .semibold)
    static let stat = Font.system(size: 30, weight: .bold, design: .rounded)
    static let mono = Font.system(size: 15, weight: .semibold, design: .monospaced)

    static func reading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func korean(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}

// MARK: - Layout

enum SoriSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40
}

extension Int {
    /// Formats a number of seconds as `m:ss`.
    var soriClock: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
