import Foundation

enum TypingText {
    private static let allowedPunctuation = Set(".,?!'\"()-:;/@#%&*+=~")

    /// True when every character can be produced by the built-in keyboard and
    /// at least one modern Hangul syllable is present.
    static func isTypeable(_ text: String) -> Bool {
        guard PracticeText.isPresentable(text) else { return false }
        var hasHangul = false

        for character in text {
            if character == " " {
                continue
            }
            if PracticeText.isHangulSyllable(character) {
                hasHangul = true
                continue
            }
            if "0123456789".contains(character) {
                continue
            }
            if allowedPunctuation.contains(character) {
                continue
            }
            return false
        }

        return hasHangul
    }
}
