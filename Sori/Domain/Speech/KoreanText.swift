import Foundation

enum KoreanText {
    static func words(in text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { word in
                word.contains { $0.isLetter || $0.isNumber }
            }
    }

    static func eojeolCount(_ text: String) -> Int {
        words(in: text).count
    }

    static func containsHangul(_ text: String) -> Bool {
        text.contains(where: PracticeText.isHangulSyllable)
    }

    static func isSpeakablePhrase(_ text: String, maxEojeol: Int = 10) -> Bool {
        let count = eojeolCount(text)
        return count > 0
            && count <= maxEojeol
            && PracticeText.isPresentable(text)
            && containsHangul(text)
    }

    /// Auto mode prefers natural sentences over dictionary entries, lists, and
    /// notation-heavy examples. Manual text is not restricted this way.
    static func isNaturalPhrase(_ text: String, maxEojeol: Int = 10) -> Bool {
        guard isSpeakablePhrase(text, maxEojeol: maxEojeol) else { return false }
        let punctuation = Set(".,?!'\"…~")
        return text.allSatisfy { character in
            character == " "
                || PracticeText.isHangulSyllable(character)
                || punctuation.contains(character)
        }
    }
}
