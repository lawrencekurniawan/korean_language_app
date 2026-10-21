import Foundation
import UIKit
import ZIPFoundation

enum EPUBImporter {
    static func document(from url: URL) async throws -> ImportedDocument {
        try await Task.detached(priority: .userInitiated) {
            try importSynchronously(from: url)
        }.value
    }

    private static func importSynchronously(from url: URL) throws -> ImportedDocument {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read, pathEncoding: nil)
        } catch {
            throw ImportError.unreadable("The EPUB archive could not be opened.")
        }

        guard let containerData = data(for: "META-INF/container.xml", in: archive) else {
            throw ImportError.unreadable("This EPUB has no container.xml.")
        }

        let container = OPFParser()
        guard parseXML(containerData, with: container),
              let opfPath = container.rootfile else {
            throw ImportError.unreadable("This EPUB has no package document.")
        }

        guard let opfData = data(for: opfPath, in: archive) else {
            throw ImportError.unreadable("The EPUB package document is missing.")
        }

        let package = OPFParser()
        guard parseXML(opfData, with: package) else {
            throw ImportError.unreadable("The EPUB package document could not be read.")
        }

        let directory = (opfPath as NSString).deletingLastPathComponent
        var chapters: [String] = []

        for idref in package.spine {
            guard let item = package.manifest[idref],
                  item.mediaType == "application/xhtml+xml" || item.mediaType == "text/html" else {
                continue
            }
            let path = resolve(item.href, relativeTo: directory)
            guard let chapterData = data(for: path, in: archive) else { continue }
            let text = HTMLTextExtractor.plainText(from: chapterData)
            if text.count >= 40, TextNormalizer.containsHangul(text) {
                chapters.append(text)
            }
        }

        let text = TextNormalizer.normalize(chapters.joined(separator: "\n\n"))
        guard !text.isEmpty else {
            throw ImportError.unreadable("No Korean text was found in this EPUB.")
        }

        let title = package.title.isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : package.title

        return ImportedDocument(
            title: title,
            text: text,
            source: "Imported EPUB",
            sourceURL: nil,
            license: nil,
            attribution: nil,
            kind: .prose
        )
    }

    private static func data(for path: String, in archive: Archive) -> Data? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
            return data
        } catch {
            return nil
        }
    }

    private static func parseXML(_ data: Data, with parser: OPFParser) -> Bool {
        let xml = XMLParser(data: data)
        xml.delegate = parser
        return xml.parse()
    }

    private static func resolve(_ href: String, relativeTo directory: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        let combined = directory.isEmpty ? decoded : directory + "/" + decoded
        var components: [String] = []
        for part in combined.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." { continue }
            if part == ".." {
                if !components.isEmpty { components.removeLast() }
            } else {
                components.append(String(part))
            }
        }
        return components.joined(separator: "/")
    }
}

private final class OPFParser: NSObject, XMLParserDelegate {
    struct ManifestItem {
        let href: String
        let mediaType: String
    }

    var rootfile: String?
    var manifest: [String: ManifestItem] = [:]
    var spine: [String] = []
    var title: String = ""

    private var titleBuffer = ""
    private var isInsideTitle = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName

        switch localName {
        case "rootfile":
            if let path = attributeDict["full-path"] {
                rootfile = path
            }
        case "item":
            if let id = attributeDict["id"],
               let href = attributeDict["href"] {
                manifest[id] = ManifestItem(
                    href: href,
                    mediaType: attributeDict["media-type"] ?? ""
                )
            }
        case "itemref":
            if let idref = attributeDict["idref"] {
                spine.append(idref)
            }
        case "title":
            isInsideTitle = true
            titleBuffer = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideTitle {
            titleBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if localName == "title", isInsideTitle {
            let value = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty, !value.isEmpty {
                title = value
            }
            isInsideTitle = false
        }
    }
}

enum HTMLTextExtractor {
    static func plainText(from data: Data) -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            let text = TextNormalizer.normalize(attributed.string)
            if !text.isEmpty {
                return text
            }
        }

        guard let raw = TextFileDecoder.decode(data) else { return "" }
        let stripped = raw
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return TextNormalizer.normalize(stripped)
    }
}
