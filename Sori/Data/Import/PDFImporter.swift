import Foundation
import PDFKit
import UIKit
import Vision

enum PDFImporter {
    /// Imports at most `pageLimit` pages so a 400-page scan cannot monopolise
    /// the device. The corpus size cap applies after text extraction as well.
    static func document(from url: URL, pageLimit: Int = 40) async throws -> ImportedDocument {
        try await Task.detached(priority: .userInitiated) {
            try importSynchronously(from: url, pageLimit: pageLimit)
        }.value
    }

    private static func importSynchronously(from url: URL, pageLimit: Int) throws -> ImportedDocument {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.unreadable("The PDF could not be opened.")
        }

        let metadataTitle = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = metadataTitle.flatMap { $0.isEmpty ? nil : $0 }
            ?? url.deletingPathExtension().lastPathComponent

        var pageTexts: [String] = []
        let count = min(document.pageCount, max(pageLimit, 1))
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            let textLayer = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if TextNormalizer.containsHangul(textLayer),
               TextNormalizer.hangulRatio(textLayer) >= 0.12,
               textLayer.count >= 20 {
                pageTexts.append(textLayer)
            } else if let recognized = recognize(page: page) {
                pageTexts.append(recognized)
            }
        }

        let text = TextNormalizer.normalize(pageTexts.joined(separator: "\n\n"))
        guard !text.isEmpty else {
            throw ImportError.unreadable("No Korean text was found in this PDF. If it is a scan, OCR may not have recognised the page layout.")
        }

        return ImportedDocument(
            title: title,
            text: text,
            source: "Imported PDF",
            sourceURL: nil,
            license: nil,
            attribution: nil,
            kind: .prose
        )
    }

    private static func recognize(page: PDFPage) -> String? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = min(2.5, 2_400 / max(bounds.width, bounds.height))
        let width = max(Int(bounds.width * scale), 1)
        let height = max(Int(bounds.height * scale), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        guard let image = context.makeImage() else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR"]
        request.usesLanguageCorrection = true

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            return nil
        }

        let observations = (request.results ?? []).sorted { left, right in
            if abs(left.boundingBox.midY - right.boundingBox.midY) < 0.02 {
                return left.boundingBox.minX < right.boundingBox.minX
            }
            return left.boundingBox.midY > right.boundingBox.midY
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let text = TextNormalizer.normalize(lines.joined(separator: "\n"))
        return TextNormalizer.containsHangul(text) ? text : nil
    }
}
