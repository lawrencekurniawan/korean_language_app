import Foundation

/// A small 2-set Hangul input method. It keeps the committed text and the
/// syllable currently being composed, so the typing view can render live input.
struct HangulComposer: Sendable, Equatable {
    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let medials = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")

    private var committed = ""
    private var initial: Int?
    private var medial: Int?
    private var final: Int?
    private var autoInitial = false

    var text: String {
        committed + currentText
    }

    private var currentText: String {
        if let initial, let medial {
            let scalar = 0xAC00 + (initial * 21 + medial) * 28 + (final ?? 0)
            return String(UnicodeScalar(scalar) ?? " ")
        }
        if let initial {
            return String(Self.initials[initial])
        }
        if let medial {
            return String(Self.medials[medial])
        }
        return ""
    }

    mutating func insertConsonant(_ index: Int) {
        guard Self.initials.indices.contains(index) else { return }

        guard initial != nil else {
            initial = index
            autoInitial = false
            return
        }

        guard medial != nil else {
            // Two consonants in a row are separate jamo in the 2-set layout.
            commitCurrent()
            initial = index
            return
        }

        guard let currentFinal = final else {
            if let finalIndex = Self.finalIndex(forInitial: index) {
                final = finalIndex
            } else {
                commitCurrent()
                initial = index
            }
            return
        }

        if let compound = Self.compoundFinal(current: currentFinal, adding: index) {
            final = compound
        } else {
            commitCurrent()
            initial = index
        }
    }

    mutating func insertVowel(_ index: Int) {
        guard Self.medials.indices.contains(index) else { return }

        guard let currentMedial = medial else {
            if initial == nil {
                initial = 11
                autoInitial = true
            }
            medial = index
            return
        }

        guard let currentFinal = final else {
            if let compound = Self.compoundVowel(current: currentMedial, adding: index) {
                medial = compound
            } else {
                commitCurrent()
                initial = 11
                autoInitial = true
                medial = index
            }
            return
        }

        let split = Self.splitFinal(currentFinal)
        final = split.remaining
        commitCurrent()
        initial = split.nextInitial
        autoInitial = false
        medial = index
    }

    mutating func insertLiteral(_ character: Character) {
        commitCurrent()
        committed.append(character)
    }

    mutating func backspace() {
        if let final {
            self.final = Self.splitFinal(final).remaining
            return
        }

        if let medial {
            if let first = Self.firstVowelComponent(of: medial) {
                self.medial = first
            } else if autoInitial {
                initial = nil
                self.medial = nil
                autoInitial = false
            } else {
                self.medial = nil
            }
            return
        }

        if initial != nil {
            initial = nil
            return
        }

        if !committed.isEmpty {
            committed.removeLast()
        }
    }

    mutating func reset() {
        committed = ""
        initial = nil
        medial = nil
        final = nil
        autoInitial = false
    }

    private mutating func commitCurrent() {
        committed += currentText
        initial = nil
        medial = nil
        final = nil
        autoInitial = false
    }

    // MARK: - Jamo maps

    private static func finalIndex(forInitial index: Int) -> Int? {
        switch index {
        case 0: 1   // ㄱ
        case 1: 2   // ㄲ
        case 2: 4   // ㄴ
        case 3: 7   // ㄷ
        case 5: 8   // ㄹ
        case 6: 16  // ㅁ
        case 7: 17  // ㅂ
        case 9: 19  // ㅅ
        case 10: 20 // ㅆ
        case 11: 21 // ㅇ
        case 12: 22 // ㅈ
        case 14: 23 // ㅊ
        case 15: 24 // ㅋ
        case 16: 25 // ㅌ
        case 17: 26 // ㅍ
        case 18: 27 // ㅎ
        default: nil
        }
    }

    private static func compoundFinal(current: Int, adding index: Int) -> Int? {
        switch (current, index) {
        case (1, 9): 3    // ㄱ + ㅅ = ㄳ
        case (4, 12): 5   // ㄴ + ㅈ = ㄵ
        case (4, 18): 6   // ㄴ + ㅎ = ㄶ
        case (8, 0): 9    // ㄹ + ㄱ = ㄺ
        case (8, 6): 10   // ㄹ + ㅁ = ㄻ
        case (8, 7): 11   // ㄹ + ㅂ = ㄼ
        case (8, 9): 12   // ㄹ + ㅅ = ㄽ
        case (8, 16): 13  // ㄹ + ㅌ = ㄾ
        case (8, 17): 14  // ㄹ + ㅍ = ㄿ
        case (8, 18): 15  // ㄹ + ㅎ = ㅀ
        case (17, 9): 18  // ㅂ + ㅅ = ㅄ
        default: nil
        }
    }

    private static func splitFinal(_ final: Int) -> (remaining: Int?, nextInitial: Int) {
        switch final {
        case 1: (nil, 0)     // ㄱ
        case 2: (nil, 1)     // ㄲ
        case 3: (1, 9)       // ㄳ
        case 4: (nil, 2)     // ㄴ
        case 5: (4, 12)      // ㄵ
        case 6: (4, 18)      // ㄶ
        case 7: (nil, 3)     // ㄷ
        case 8: (nil, 5)     // ㄹ
        case 9: (8, 0)       // ㄺ
        case 10: (8, 6)      // ㄻ
        case 11: (8, 7)      // ㄼ
        case 12: (8, 9)      // ㄽ
        case 13: (8, 16)     // ㄾ
        case 14: (8, 17)     // ㄿ
        case 15: (8, 18)     // ㅀ
        case 16: (nil, 6)    // ㅁ
        case 17: (nil, 7)    // ㅂ
        case 18: (17, 9)     // ㅄ
        case 19: (nil, 9)    // ㅅ
        case 20: (nil, 10)   // ㅆ
        case 21: (nil, 11)   // ㅇ
        case 22: (nil, 12)   // ㅈ
        case 23: (nil, 14)   // ㅊ
        case 24: (nil, 15)   // ㅋ
        case 25: (nil, 16)   // ㅌ
        case 26: (nil, 17)   // ㅍ
        case 27: (nil, 18)   // ㅎ
        default: (nil, 11)
        }
    }

    private static func compoundVowel(current: Int, adding index: Int) -> Int? {
        switch (current, index) {
        case (8, 0): 9     // ㅗ + ㅏ = ㅘ
        case (8, 1): 10    // ㅗ + ㅐ = ㅙ
        case (8, 20): 11   // ㅗ + ㅣ = ㅚ
        case (13, 4): 14   // ㅜ + ㅓ = ㅝ
        case (13, 5): 15   // ㅜ + ㅔ = ㅞ
        case (13, 20): 16  // ㅜ + ㅣ = ㅟ
        case (18, 20): 19  // ㅡ + ㅣ = ㅢ
        default: nil
        }
    }

    private static func firstVowelComponent(of index: Int) -> Int? {
        switch index {
        case 9: 8
        case 10: 8
        case 11: 8
        case 14: 13
        case 15: 13
        case 16: 13
        case 19: 18
        default: nil
        }
    }
}

struct TypingInputState: Sendable, Equatable {
    var text = ""
    private var composer = HangulComposer()

    mutating func press(_ key: TypingKey) {
        switch key {
        case .consonant(let index):
            composer.insertConsonant(index)
        case .vowel(let index):
            composer.insertVowel(index)
        case .literal(let character):
            composer.insertLiteral(character)
        case .space:
            composer.insertLiteral(" ")
        case .backspace:
            composer.backspace()
        }
        text = composer.text
    }

    mutating func reset() {
        composer.reset()
        text = ""
    }
}
