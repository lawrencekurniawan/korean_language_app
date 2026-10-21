import Foundation

enum PlainTextImporter {
    static func document(from url: URL, title: String? = nil) throws -> ImportedDocument {
        let data = try Data(contentsOf: url)
        guard let text = TextFileDecoder.decode(data) else {
            throw ImportError.unreadable("The text encoding could not be detected.")
        }
        let resolvedTitle = title ?? url.deletingPathExtension().lastPathComponent
        return ImportedDocument(
            title: resolvedTitle,
            text: text,
            source: "Imported text",
            sourceURL: nil,
            license: nil,
            attribution: nil,
            kind: .prose
        )
    }
}
