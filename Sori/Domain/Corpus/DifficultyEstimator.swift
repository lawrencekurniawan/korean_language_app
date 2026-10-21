import Foundation

/// Provisional deterministic difficulty estimate for library sentences.
///
/// The authored curriculum carries its own difficulty labels. Imported and
/// seeded library text is ranked with this lightweight heuristic so practice can
/// filter by rough level without pretending to be a vocabulary analyser.
enum DifficultyEstimator {
    static func estimate(_ sentence: String) -> Int {
        let text = TextNormalizer.normalize(sentence)
        let nonWhitespace = TextNormalizer.nonWhitespaceCount(text)
        let eojeol = max(TextNormalizer.eojeolCount(text), 1)
        let averageEojeolLength = Double(nonWhitespace) / Double(eojeol)
        let clauses = text.filter { $0 == "," || $0 == "·" || $0 == ";" }.count
        let hanja = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }

        var score = 1
        if eojeol > 8 { score += 1 }
        if eojeol > 14 { score += 1 }
        if nonWhitespace > 45 { score += 1 }
        if nonWhitespace > 80 { score += 1 }
        if averageEojeolLength > 3.5 { score += 1 }
        if clauses >= 2 { score += 1 }
        if hanja { score += 1 }
        return min(max(score, 1), 6)
    }

    static func articleDifficulty(_ sentences: [String]) -> Int? {
        guard !sentences.isEmpty else { return nil }
        let values = sentences.map(estimate).sorted()
        return values[values.count / 2]
    }
}
