import Foundation

/// Dependency-free RGB PNG encoder. Uses DEFLATE stored blocks so it does not
/// require a platform zlib module or an external compression package.
public enum ThumbnailPNGEncoder {
    private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    public static func gradient(size: Int = MomentThumbnailConstants.size, colors: ThumbnailGradient) throws -> Data {
        guard size > 0, size <= 4096 else {
            throw MomentThumbnailError.invalidPNG("Image dimensions must be between 1 and 4096 pixels.")
        }
        let (pixelCount, overflow1) = size.multipliedReportingOverflow(by: size)
        let (byteCount, overflow2) = pixelCount.multipliedReportingOverflow(by: 3)
        guard !overflow1, !overflow2, byteCount <= 256 * 1024 * 1024 else {
            throw MomentThumbnailError.invalidPNG("Requested image dimensions exceed the memory limit.")
        }

        var scanlines = Data(capacity: byteCount + size)
        let denominator = Double(max(size - 1, 1))
        for y in 0..<size {
            scanlines.append(0) // PNG filter type: None.
            let t = Double(y) / denominator
            for x in 0..<size {
                let u = (Double(x) / denominator + t) / 2.0
                scanlines.append(interpolate(colors.start.red, colors.end.red, u))
                scanlines.append(interpolate(colors.start.green, colors.end.green, u))
                scanlines.append(interpolate(colors.start.blue, colors.end.blue, u))
            }
        }

        var ihdr = Data()
        ihdr.appendUInt32BE(UInt32(size))
        ihdr.appendUInt32BE(UInt32(size))
        ihdr.append(contentsOf: [8, 2, 0, 0, 0]) // 8-bit truecolor RGB.

        var png = Data(signature)
        png.appendChunk(type: "IHDR", payload: ihdr)
        png.appendChunk(type: "IDAT", payload: zlibStoredStream(scanlines))
        png.appendChunk(type: "IEND", payload: Data())
        return png
    }

    private static func interpolate(_ start: UInt8, _ end: UInt8, _ t: Double) -> UInt8 {
        let value = Double(start) + (Double(end) - Double(start)) * t
        return UInt8(max(0, min(255, Int(value))))
    }

    private static func zlibStoredStream(_ input: Data) -> Data {
        var output = Data([0x78, 0x01]) // Deflate, fastest/no-compression hint.
        var offset = 0
        while offset < input.count {
            let length = min(65_535, input.count - offset)
            let isFinal = offset + length == input.count
            output.append(isFinal ? 0x01 : 0x00) // BFINAL and BTYPE=00, byte aligned.
            let len = UInt16(length)
            let nlen = ~len
            output.append(UInt8(len & 0xff))
            output.append(UInt8((len >> 8) & 0xff))
            output.append(UInt8(nlen & 0xff))
            output.append(UInt8((nlen >> 8) & 0xff))
            output.append(input.subdata(in: offset..<(offset + length)))
            offset += length
        }
        if input.isEmpty {
            output.append(contentsOf: [0x01, 0x00, 0x00, 0xff, 0xff])
        }
        output.appendUInt32BE(adler32(input))
        return output
    }

    private static func adler32(_ data: Data) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in data {
            a = (a + UInt32(byte)) % 65_521
            b = (b + a) % 65_521
        }
        return (b << 16) | a
    }

    fileprivate static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1
            }
        }
        return crc ^ 0xffff_ffff
    }
}

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendChunk(type: String, payload: Data) {
        let tag = Data(type.utf8)
        appendUInt32BE(UInt32(payload.count))
        append(tag)
        append(payload)
        var checksumInput = Data(tag)
        checksumInput.append(payload)
        appendUInt32BE(ThumbnailPNGEncoder.crc32(checksumInput))
    }
}
