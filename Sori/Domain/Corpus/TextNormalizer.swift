import CryptoKit
import Foundation

enum TextNormalizer {
    /// Canonical form used for display and storage.
    static func normalize(_ text: String) -> String {
        var value = text.precomposedStringWithCanonicalMapping
        value = value.replacingOccurrences(of: "\r\n", with: "\n")
        value = value.replacingOccurrences(of: "\r", with: "\n")
        value = value.replacingOccurrences(of: "\u{00A0}", with: " ")
        value = value.replacingOccurrences(of: "\u{200B}", with: "")
        value = value.replacingOccurrences(of: "\u{FEFF}", with: "")
        value = value.replacingOccurrences(of: "\t", with: " ")
        value = value.replacingOccurrences(
            of: "[ ]{2,}",
            with: " ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: "\n[ ]+",
            with: "\n",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whitespace-insensitive form used for duplicate detection.
    static func normalizedForHash(_ text: String) -> String {
        normalize(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ko_KR"))
    }

    static func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// CPM counts non-whitespace characters, never spaces or newlines.
    static func nonWhitespaceCount(_ text: String) -> Int {
        text.reduce(into: 0) { count, character in
            if !character.isWhitespace {
                count += 1
            }
        }
    }

    static func eojeolCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    static func hangulRatio(_ text: String) -> Double {
        var hangul = 0
        var meaningful = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            meaningful += 1
            let value = scalar.value
            if (0xAC00...0xD7A3).contains(value)
                || (0x1100...0x11FF).contains(value)
                || (0x3130...0x318F).contains(value)
                || (0xA960...0xA97F).contains(value)
                || (0xD7B0...0xD7FF).contains(value) {
                hangul += 1
            }
        }
        guard meaningful > 0 else { return 0 }
        return Double(hangul) / Double(meaningful)
    }

    static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)
        }
    }

    static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
