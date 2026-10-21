import Foundation

enum PracticeText {
    private static let validStarts = Set("\"'([“‘「『")
    private static let validEndings = Set(".?!\"')]…”’")

    /// Filters out headings, list fragments, and lines that do not look like a
    /// complete sentence before they reach a practice session.
    static func isPresentable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4, let first = trimmed.first, let last = trimmed.last else {
            return false
        }
        guard isHangulSyllable(first) || first.isNumber || validStarts.contains(first) else {
            return false
        }
        return validEndings.contains(last)
    }

    static func isHangulSyllable(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }
        return (0xAC00...0xD7A3).contains(scalar.value)
    }
}
