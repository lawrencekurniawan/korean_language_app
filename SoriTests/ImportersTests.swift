import CoreFoundation
import UIKit
import XCTest
import ZIPFoundation
@testable import Sori

final class ImportersTests: XCTestCase {
    func testPlainTextDecoderFallsBackToEUCKR() throws {
        let encoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
            )
        )
        let original = "안녕하세요. 오늘은 날씨가 좋습니다."
        let data = try XCTUnwrap(original.data(using: encoding))
        XCTAssertEqual(TextFileDecoder.decode(data), original)
    }

    func testPDFImporterReadsTextLayer() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sori-pdf-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26)
            ]
            ("안녕하세요. 오늘은 날씨가 좋습니다." as NSString).draw(
                in: CGRect(x: 72, y: 72, width: 468, height: 120),
                withAttributes: attributes
            )
        }
        try data.write(to: url)

        let document = try await PDFImporter.document(from: url)
        XCTAssertTrue(document.text.contains("안녕하세요"))
        XCTAssertEqual(document.source, "Imported PDF")
    }

    func testEPUBImporterReadsSpineChapter() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sori-epub-\(UUID().uuidString).epub")
        defer { try? FileManager.default.removeItem(at: url) }

        let archive = try Archive(url: url, accessMode: .create)
        try add(
            "mimetype",
            "application/epub+zip",
            to: archive,
            compression: .none
        )
        try add(
            "META-INF/container.xml",
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """,
            to: archive
        )
        try add(
            "OEBPS/content.opf",
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>테스트 책</dc:title>
              </metadata>
              <manifest>
                <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
              </manifest>
              <spine>
                <itemref idref="chapter1"/>
              </spine>
            </package>
            """,
            to: archive
        )
        try add(
            "OEBPS/chapter1.xhtml",
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head><title>Chapter</title></head>
              <body>
                <h1>첫 번째 장</h1>
                <p>안녕하세요. 오늘은 날씨가 좋습니다.</p>
                <p>저는 한국어를 공부해요.</p>
              </body>
            </html>
            """,
            to: archive
        )

        let document = try await EPUBImporter.document(from: url)
        XCTAssertEqual(document.title, "테스트 책")
        XCTAssertTrue(document.text.contains("안녕하세요"))
        XCTAssertTrue(document.text.contains("첫 번째 장"))
    }

    func testSubtitleArchiveExtractsSRTFromZip() throws {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sori-subtitle-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let archive = try Archive(url: zipURL, accessMode: .create)
        let srt = """
        1
        00:00:01,000 --> 00:00:03,000
        안녕하세요.
        """
        try add("Korean.srt", srt, to: archive)

        let result = try SubtitleArchive.extract(
            data: Data(contentsOf: zipURL),
            fileName: "download.zip"
        )
        XCTAssertEqual(result.format, .srt)
        XCTAssertTrue(String(data: result.data, encoding: .utf8)?.contains("안녕하세요") == true)
    }

    private func add(
        _ path: String,
        _ string: String,
        to archive: Archive,
        compression: CompressionMethod = .deflate
    ) throws {
        let data = Data(string.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: compression
        ) { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }
}
