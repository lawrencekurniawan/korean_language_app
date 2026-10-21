import SwiftUI

// MARK: - Card

struct SoriCard<Content: View>: View {
    var padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = SoriSpacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.soriSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.soriBorder, lineWidth: 1)
            )
    }
}

// MARK: - Headers

struct SoriSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<T: View>(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                if let subtitle {
                    Text(subtitle)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
            }
            Spacer(minLength: SoriSpacing.sm)
            if let trailing {
                trailing
            }
        }
    }
}

// MARK: - Badge

struct SoriBadge: View {
    let text: String
    var tint: Color = .soriAccent

    var body: some View {
        Text(text)
            .font(SoriFont.captionStrong)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - Stat tile

struct SoriStatTile: View {
    let label: String
    let value: String
    var unit: String?
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.xs) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(Color.soriSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SoriFont.stat)
                    .foregroundStyle(Color.soriInk)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(SoriFont.captionStrong)
                        .foregroundStyle(Color.soriSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SoriSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.soriSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.soriBorder, lineWidth: 1)
        )
    }
}

// MARK: - Empty state

struct SoriEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: SoriSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.soriTertiary)
            Text(title)
                .font(SoriFont.headline)
                .foregroundStyle(Color.soriInk)
            Text(message)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SoriSpacing.xl)
    }
}

// MARK: - Button styles

struct SoriPrimaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SoriFont.headline)
            .foregroundStyle(Color.soriBackground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, SoriSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.soriAccent)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoriSecondaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SoriFont.callout)
            .foregroundStyle(Color.soriInk)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 13)
            .padding(.horizontal, SoriSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.soriSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.soriBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct SoriDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SoriFont.callout)
            .foregroundStyle(Color.soriError)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.soriError.opacity(0.10))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Screen background

extension View {
    func soriScreenBackground() -> some View {
        background(Color.soriBackground.ignoresSafeArea())
    }
}
