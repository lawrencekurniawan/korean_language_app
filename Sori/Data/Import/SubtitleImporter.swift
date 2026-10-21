import Foundation

enum SubtitleFormat: String, Sendable {
    case srt
    case vtt

    static func from(fileName: String) -> SubtitleFormat? {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "srt": .srt
        case "vtt": .vtt
        default: nil
        }
    }
}

struct SubtitleCue: Sendable, Equatable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum SubtitleImporter {
    static func document(
        from data: Data,
        title: String,
        format: SubtitleFormat,
        source: String = "Imported subtitle",
        sourceURL: URL? = nil,
        license: String? = nil,
        attribution: String? = nil
    ) throws -> ImportedDocument {
        guard let raw = TextFileDecoder.decode(data) else {
            throw ImportError.unreadable("The subtitle encoding could not be detected.")
        }

        let cues = parse(raw, format: format)
        let cleaned = cues
            .map { SubtitleCue(start: $0.start, end: $0.end, text: cleanCueText($0.text)) }
            .filter { !$0.text.isEmpty && TextNormalizer.containsHangul($0.text) }

        guard !cleaned.isEmpty else { throw ImportError.noSubtitles }

        let text = assemble(cleaned)
        guard TextNormalizer.containsHangul(text),
              TextNormalizer.hangulRatio(text) >= 0.10 else {
            throw ImportError.noKoreanText
        }

        return ImportedDocument(
            title: title,
            text: text,
            source: source,
            sourceURL: sourceURL,
            license: license,
            attribution: attribution,
            kind: .subtitle
        )
    }

    static func parse(_ text: String, format: SubtitleFormat) -> [SubtitleCue] {
        let normalized = TextNormalizer.normalize(text)
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []

        for rawBlock in blocks {
            var lines = rawBlock
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            if format == .vtt {
                let first = lines[0].uppercased()
                if first.hasPrefix("NOTE") || first.hasPrefix("STYLE") || first.hasPrefix("REGION") {
                    continue
                }
                if first.hasPrefix("WEBVTT") {
                    lines.removeFirst()
                }
            }

            guard !lines.isEmpty,
                  let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }
            guard let cue = cue(from: lines[timingIndex]) else { continue }

            let textLines = Array(lines[(timingIndex + 1)...])
            let cueText = textLines.joined(separator: " ")
            guard !cueText.isEmpty else { continue }
            cues.append(SubtitleCue(start: cue.start, end: cue.end, text: cueText))
        }

        return cues
    }

    private static func cue(from line: String) -> (start: TimeInterval, end: TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startText = parts[0].trimmingCharacters(in: .whitespaces)
        let endText = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
        guard let start = parseTimestamp(startText), let end = parseTimestamp(endText) else {
            return nil
        }
        return (start, max(end, start))
    }

    private static func parseTimestamp(_ value: String) -> TimeInterval? {
        let cleaned = value.replacingOccurrences(of: ",", with: ".")
        let pieces = cleaned.split(separator: ":").map(String.init)
        guard !pieces.isEmpty, pieces.count <= 3 else { return nil }

        let seconds: Double
        switch pieces.count {
        case 3:
            guard let hours = Double(pieces[0]),
                  let minutes = Double(pieces[1]),
                  let secs = Double(pieces[2]) else { return nil }
            seconds = hours * 3600 + minutes * 60 + secs
        case 2:
            guard let minutes = Double(pieces[0]),
                  let secs = Double(pieces[1]) else { return nil }
            seconds = minutes * 60 + secs
        case 1:
            guard let secs = Double(pieces[0]) else { return nil }
            seconds = secs
        default:
            return nil
        }
        return seconds
    }

    static func cleanCueText(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(of: "\\N", with: " ")
        value = value.replacingOccurrences(of: "\\n", with: " ")
        value = value.replacingOccurrences(of: "♪", with: "")
        value = value.replacingOccurrences(
            of: "\\{[^}]*\\}",
            with: " ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let soundWords = "음악|웃음|박수|효과음|문\\s*소리|전화\\s*소리|발소리|숨소리|한숨|비명|고함|침묵|노래"
        value = value.replacingOccurrences(
            of: "\\[[^\\]]*(?:\(soundWords))[^\\]]*\\]",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(
            of: "\\([^\\)]*(?:\(soundWords))[^\\)]*\\)",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(
            of: "^[\\s]*[-–—][\\s]*",
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: "\\s{2,}",
            with: " ",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func assemble(_ cues: [SubtitleCue]) -> String {
        var output = ""
        var previousEnd: TimeInterval?
        for cue in cues {
            if let previousEnd, cue.start - previousEnd > 1.5 {
                output += "\n\n"
            } else if !output.isEmpty {
                output += " "
            }
            output += cue.text
            previousEnd = cue.end
        }
        return TextNormalizer.normalize(output)
    }
}
