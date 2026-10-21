import SwiftUI

struct TypingKeyboardView: View {
    let onKey: (TypingKey) -> Void

    @State private var layer: KeyboardLayer = .hangul
    @State private var isShifted = false

    private enum KeyboardLayer {
        case hangul
        case symbols
    }

    private struct KeySpec {
        let title: String?
        let image: String?
        let action: Action
        let width: CGFloat?

        enum Action {
            case input(TypingKey)
            case shift
            case layer
        }

        static func consonant(_ index: Int, _ label: String) -> KeySpec {
            KeySpec(title: label, image: nil, action: .input(.consonant(index)), width: nil)
        }

        static func vowel(_ index: Int, _ label: String) -> KeySpec {
            KeySpec(title: label, image: nil, action: .input(.vowel(index)), width: nil)
        }

        static func literal(_ value: String) -> KeySpec {
            KeySpec(
                title: value,
                image: nil,
                action: .input(.literal(Character(value))),
                width: nil
            )
        }

        static func space(width: CGFloat? = nil) -> KeySpec {
            KeySpec(title: "space", image: nil, action: .input(.space), width: width)
        }

        static func backspace(width: CGFloat? = nil) -> KeySpec {
            KeySpec(
                title: nil,
                image: "delete.left",
                action: .input(.backspace),
                width: width
            )
        }

        static func shift() -> KeySpec {
            KeySpec(title: nil, image: "shift", action: .shift, width: nil)
        }

    }

    var body: some View {
        VStack(spacing: 6) {
            if layer == .hangul {
                hangulKeyboard
            } else {
                symbolKeyboard
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .background(Color.soriSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.soriBorder)
                .frame(height: 1)
        }
    }

    private var hangulKeyboard: some View {
        VStack(spacing: 6) {
            keyRow(
                isShifted
                    ? [
                        .consonant(8, "ㅃ"), .consonant(13, "ㅉ"), .consonant(4, "ㄸ"),
                        .consonant(1, "ㄲ"), .consonant(10, "ㅆ"), .vowel(12, "ㅛ"),
                        .vowel(6, "ㅕ"), .vowel(2, "ㅑ"), .vowel(3, "ㅒ"), .vowel(7, "ㅖ")
                    ]
                    : [
                        .consonant(7, "ㅂ"), .consonant(12, "ㅈ"), .consonant(3, "ㄷ"),
                        .consonant(0, "ㄱ"), .consonant(9, "ㅅ"), .vowel(12, "ㅛ"),
                        .vowel(6, "ㅕ"), .vowel(2, "ㅑ"), .vowel(1, "ㅐ"), .vowel(5, "ㅔ")
                    ]
            )

            keyRow([
                .consonant(6, "ㅁ"), .consonant(2, "ㄴ"), .consonant(11, "ㅇ"),
                .consonant(5, "ㄹ"), .consonant(18, "ㅎ"), .vowel(8, "ㅗ"),
                .vowel(4, "ㅓ"), .vowel(0, "ㅏ"), .vowel(20, "ㅣ"), .backspace()
            ])

            keyRow([
                .shift(), .consonant(15, "ㅋ"), .consonant(16, "ㅌ"),
                .consonant(14, "ㅊ"), .consonant(17, "ㅍ"), .vowel(17, "ㅠ"),
                .vowel(13, "ㅜ"), .vowel(18, "ㅡ"), layerKey(title: "?123")
            ])

            HStack(spacing: 6) {
                keyButton(.space(), title: "space", width: nil)
                keyButton(.literal("."), title: ".", width: 42)
                keyButton(.literal(","), title: ",", width: 42)
                keyButton(.literal("?"), title: "?", width: 42)
            }
        }
    }

    private var symbolKeyboard: some View {
        VStack(spacing: 6) {
            keyRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map(KeySpec.literal))

            keyRow([
                .literal("-"), .literal("/"), .literal(":"), .literal(";"),
                .literal("("), .literal(")"), .literal("!"), .literal("?"),
                .literal("."), .literal(",")
            ])

            keyRow([
                .literal("\""), .literal("'"), .literal("@"), .literal("#"),
                .literal("%"), .literal("&"), .literal("*"), .literal("+"),
                .literal("="), .literal("~")
            ])

            HStack(spacing: 6) {
                keyButton(layerKey(title: "한글"), title: "한글", width: 62)
                keyButton(.space(), title: "space", width: nil)
                keyButton(.backspace(), title: nil, width: 52)
            }
        }
    }

    private func keyRow(_ keys: [KeySpec]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keyButton(key, title: key.title, width: key.width)
            }
        }
    }

    private func layerKey(title: String) -> KeySpec {
        KeySpec(
            title: title,
            image: nil,
            action: .layer,
            width: nil
        )
    }

    private func keyButton(_ spec: KeySpec, title: String?, width: CGFloat?) -> some View {
        Button {
            handle(spec.action)
        } label: {
            Group {
                if let image = spec.image {
                    Image(systemName: image)
                        .font(.system(size: 18, weight: .medium))
                } else {
                    Text(title ?? "")
                        .font(.system(
                            size: (title?.count ?? 0) > 2 ? 13 : 19,
                            weight: .medium
                        ))
                }
            }
            .foregroundStyle(foreground(for: spec))
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width)
            .frame(height: 46)
            .background(
                background(for: spec),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TypingKeyPressStyle())
        .accessibilityLabel(accessibilityLabel(for: spec, title: title))
    }

    private func handle(_ action: KeySpec.Action) {
        switch action {
        case .shift:
            isShifted.toggle()
        case .layer:
            layer = layer == .hangul ? .symbols : .hangul
            isShifted = false
        case .input(let key):
            onKey(key)
            isShifted = false
        }
    }

    private func foreground(for spec: KeySpec) -> Color {
        if case .shift = spec.action, isShifted {
            return .soriBackground
        }
        return .soriInk
    }

    private func background(for spec: KeySpec) -> Color {
        if case .shift = spec.action, isShifted {
            return .soriAccent
        }
        return .soriSurfaceElevated
    }

    private func accessibilityLabel(for spec: KeySpec, title: String?) -> String {
        switch spec.action {
        case .shift:
            return isShifted ? "Shift on" : "Shift"
        case .layer:
            return layer == .hangul ? "Symbols" : "Hangul"
        case .input(let key):
            if case .backspace = key { return "Delete" }
            if case .space = key { return "Space" }
            return title ?? ""
        }
    }
}

private struct TypingKeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
