import Foundation

/// Splits Korean prose into practice-sized sentences without rewriting the text.
///
/// Korean sentences end with the same punctuation as English, but PDF text and
/// subtitles often contain hard line breaks mid-sentence. The segmenter joins
/// single newlines, keeps blank-line paragraph boundaries, and only splits after
/// terminal punctuation followed by whitespace.
enum SentenceSegmenter {
    private static let terminalPunctuation = CharacterSet(charactersIn: ".!?。！？…")
    private static let trailingClosers = CharacterSet(charactersIn: "”’\"')]】」』")

    static func sentences(from text: String) -> [String] {
        let normalized = TextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return [] }

        var results: [String] = []
        for paragraph in paragraphs(from: normalized) {
            let pieces = splitParagraph(paragraph)
            for piece in pieces {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isMeaningful(trimmed) else { continue }
                for chunk in splitLongSegment(trimmed) {
                    let cleaned = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isMeaningful(cleaned) {
                        results.append(cleaned)
                    }
                }
            }
        }
        return results
    }

    private static func paragraphs(from text: String) -> [String] {
        let marker = "\u{2029}"
        var value = text.replacingOccurrences(
            of: "\n{2,}",
            with: marker,
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: "\n", with: " ")
        return value
            .components(separatedBy: marker)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func splitParagraph(_ paragraph: String) -> [String] {
        var results: [String] = []
        var sentenceStart = paragraph.startIndex
        var index = paragraph.startIndex

        while index < paragraph.endIndex {
            let character = paragraph[index]
            guard let scalar = character.unicodeScalars.first,
                  terminalPunctuation.contains(scalar) else {
                index = paragraph.index(after: index)
                continue
            }

            var cursor = paragraph.index(after: index)
            while cursor < paragraph.endIndex {
                let next = paragraph[cursor]
                guard let nextScalar = next.unicodeScalars.first,
                      terminalPunctuation.contains(nextScalar) || trailingClosers.contains(nextScalar) else {
                    break
                }
                cursor = paragraph.index(after: cursor)
            }

            let isEnd = cursor == paragraph.endIndex
            let followedBySpace = !isEnd && paragraph[cursor].isWhitespace
            if isEnd || followedBySpace {
                let sentence = paragraph[sentenceStart..<cursor]
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results.append(trimmed)
                }
                sentenceStart = cursor
                while sentenceStart < paragraph.endIndex && paragraph[sentenceStart].isWhitespace {
                    sentenceStart = paragraph.index(after: sentenceStart)
                }
                index = sentenceStart
            } else {
                index = cursor
            }
        }

        let tail = paragraph[sentenceStart...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            results.append(tail)
        }
        return results
    }

    private static func splitLongSegment(_ segment: String, maximumLength: Int = 220) -> [String] {
        guard segment.count > maximumLength else { return [segment] }

        var remaining = segment
        var chunks: [String] = []
        while remaining.count > maximumLength {
            let window = String(remaining.prefix(maximumLength))
            let breakIndex = lastBreakIndex(in: window) ?? window.endIndex
            let chunk = String(remaining[..<breakIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if chunk.isEmpty {
                break
            }
            chunks.append(chunk)
            remaining = String(remaining[breakIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !remaining.isEmpty {
            chunks.append(remaining)
        }
        return chunks
    }

    private static func lastBreakIndex(in window: String) -> String.Index? {
        let candidates = [", ", "·", " - ", " "]
        for candidate in candidates {
            if let range = window.range(of: candidate, options: .backwards),
               window.distance(from: window.startIndex, to: range.lowerBound) > window.count / 3 {
                return range.lowerBound
            }
        }
        return nil
    }

    private static func isMeaningful(_ sentence: String) -> Bool {
        guard TextNormalizer.nonWhitespaceCount(sentence) >= 2 else { return false }
        return TextNormalizer.containsHangul(sentence)
            || sentence.contains { $0.isLetter }
    }
}
