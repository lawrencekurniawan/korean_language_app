import Foundation

enum TypingKey: Sendable, Equatable {
    case consonant(Int)
    case vowel(Int)
    case literal(Character)
    case space
    case backspace
}
