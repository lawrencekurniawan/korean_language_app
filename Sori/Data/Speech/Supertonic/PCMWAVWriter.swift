import Foundation

/// Minimal 16-bit PCM WAV writer for Supertonic's 44.1 kHz mono Float32 output.
enum PCMWAVWriter {
    static func data(samples: [Float], sampleRate: Int) -> Data {
        let channelCount = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let dataByteCount = samples.count * bytesPerSample
        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample

        var data = Data(capacity: 44 + dataByteCount)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32(UInt32(36 + dataByteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32(16)
        data.appendUInt16(1)
        data.appendUInt16(UInt16(channelCount))
        data.appendUInt32(UInt32(sampleRate))
        data.appendUInt32(UInt32(byteRate))
        data.appendUInt16(UInt16(blockAlign))
        data.appendUInt16(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32(UInt32(dataByteCount))

        data.reserveCapacity(44 + dataByteCount)
        for sample in samples {
            let clamped = min(max(sample, -1), 1)
            let value = Int16(clamped * Float(Int16.max))
            data.appendUInt16(UInt16(bitPattern: value))
        }
        return data
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
