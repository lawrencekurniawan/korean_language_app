import CoreFoundation
import Foundation

enum TextFileDecoder {
    /// Decodes Korean text files. Subtitle downloads in particular are often
    /// CP949/EUC-KR even today, so UTF-8 alone is not enough.
    static func decode(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        let eucKR = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
            )
        )
        if let korean = String(data: data, encoding: eucKR) {
            return korean
        }

        let cp949 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.dosKorean.rawValue)
            )
        )
        if let korean = String(data: data, encoding: cp949) {
            return korean
        }

        return String(data: data, encoding: .windowsCP1252)
    }
}
