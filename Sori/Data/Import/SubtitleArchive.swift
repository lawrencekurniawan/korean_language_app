import Foundation
import ZIPFoundation

enum SubtitleArchive {
    static func extract(data: Data, fileName: String) throws -> (data: Data, format: SubtitleFormat) {
        if let format = SubtitleFormat.from(fileName: fileName) {
            return (data, format)
        }

        if data.starts(with: [0x50, 0x4B]) {
            return try extractFromZip(data: data)
        }

        if let text = TextFileDecoder.decode(data) {
            if text.uppercased().contains("WEBVTT") {
                return (data, .vtt)
            }
            if text.contains("-->") {
                return (data, .srt)
            }
        }

        throw ImportError.unsupportedFormat((fileName as NSString).pathExtension.lowercased())
    }

    private static func extractFromZip(data: Data) throws -> (data: Data, format: SubtitleFormat) {
        let directory = FileManager.default.temporaryDirectory
        let zipURL = directory.appendingPathComponent("sori-subtitle-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try data.write(to: zipURL, options: .atomic)

        let archive = try Archive(url: zipURL, accessMode: .read)
        let preferred = archive
            .filter { $0.type == .file }
            .filter { !$0.path.contains("__MACOSX") }
            .compactMap { entry -> (Entry, SubtitleFormat)? in
                guard let format = SubtitleFormat.from(fileName: entry.path) else { return nil }
                return (entry, format)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 == .srt }
                return lhs.0.path < rhs.0.path
            }

        guard let (entry, format) = preferred.first else {
            throw ImportError.noSubtitles
        }

        var extracted = Data()
        _ = try archive.extract(entry) { extracted.append($0) }
        guard !extracted.isEmpty else { throw ImportError.noSubtitles }
        return (extracted, format)
    }
}
