import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public protocol MomentThumbnailHTTPClient: Sendable {
    func get(_ url: URL, timeout: TimeInterval, headers: [String: String]) async throws -> Data
}

public struct URLSessionThumbnailHTTPClient: MomentThumbnailHTTPClient {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, timeout: TimeInterval, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MomentThumbnailError.filesystem("Twemoji request returned HTTP \(http.statusCode).")
        }
        guard !data.isEmpty else { throw MomentThumbnailError.filesystem("Twemoji response was empty.") }
        return data
    }
}

public protocol MomentThumbnailImageProcessor: Sendable {
    /// Returns processed JPEG bytes when it can generate a native thumbnail.
    /// Returning nil requests the service's source-compatible PNG fallback.
    func makeJPEG(moment: MomentThumbnail, gradient: ThumbnailGradient, emojiPNG: Data?, userImagesDirectory: URL?) throws -> Data?
}

public struct MomentThumbnailConfiguration: Sendable {
    public let momentsDirectory: URL
    public let userImagesDirectory: URL?
    public let requestTimeout: TimeInterval
    public let maximumEmojiBytes: Int
    public let maximumRecentCount: Int

    public init(
        momentsDirectory: URL,
        userImagesDirectory: URL? = nil,
        requestTimeout: TimeInterval = 8,
        maximumEmojiBytes: Int = 4 * 1024 * 1024,
        maximumRecentCount: Int = 500
    ) {
        self.momentsDirectory = momentsDirectory
        self.userImagesDirectory = userImagesDirectory
        self.requestTimeout = max(0.1, requestTimeout)
        self.maximumEmojiBytes = max(1, maximumEmojiBytes)
        self.maximumRecentCount = max(1, maximumRecentCount)
    }
}

public actor MomentThumbnailService {
    private let configuration: MomentThumbnailConfiguration
    private let fileManager: FileManager
    private let httpClient: any MomentThumbnailHTTPClient
    private let imageProcessor: (any MomentThumbnailImageProcessor)?

    public init(
        configuration: MomentThumbnailConfiguration,
        httpClient: any MomentThumbnailHTTPClient = URLSessionThumbnailHTTPClient(),
        imageProcessor: (any MomentThumbnailImageProcessor)? = MomentThumbnailService.defaultImageProcessor(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.imageProcessor = imageProcessor
        self.fileManager = fileManager
    }

    public static func defaultImageProcessor() -> (any MomentThumbnailImageProcessor)? {
        #if canImport(ImageIO) && canImport(CoreGraphics)
        return AppleMomentThumbnailProcessor()
        #else
        return nil
        #endif
    }

    public func thumbnailsDirectory() throws -> URL {
        let directory = configuration.momentsDirectory.appendingPathComponent(MomentThumbnailConstants.thumbnailDirectoryName, isDirectory: true)
        try createDirectory(directory)
        return directory
    }

    public func emojiCacheDirectory() throws -> URL {
        let directory = try thumbnailsDirectory().appendingPathComponent(MomentThumbnailConstants.emojiCacheDirectoryName, isDirectory: true)
        try createDirectory(directory)
        return directory
    }

    public func thumbnailURL(momentID: String, extension ext: String = ".jpg") throws -> URL {
        let safe = Self.sanitizedIdentifier(momentID.isEmpty ? "unknown" : momentID)
        return try thumbnailsDirectory().appendingPathComponent(safe + Self.normalizedExtension(ext), isDirectory: false)
    }

    public func existingThumbnailURL(momentID: String) throws -> URL? {
        for ext in [".jpg", ".jpeg", ".png"] {
            let candidate = try thumbnailURL(momentID: momentID, extension: ext)
            if fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    public func generateThumbnail(for moment: MomentThumbnail, force: Bool = false) async throws -> URL? {
        guard !moment.id.isEmpty else { return nil }
        if !force, let cached = try existingThumbnailURL(momentID: moment.id) { return cached }

        let gradient = Self.gradient(forMomentID: moment.id)
        let emoji = Self.firstEmoji(in: moment.images)
        let emojiPNG = try await fetchTwemojiIfNeeded(emoji)

        if let processor = imageProcessor,
           let jpeg = try processor.makeJPEG(
                moment: moment,
                gradient: gradient,
                emojiPNG: emojiPNG,
                userImagesDirectory: configuration.userImagesDirectory
           ) {
            let output = try thumbnailURL(momentID: moment.id, extension: ".jpg")
            try atomicWrite(jpeg, to: output)
            return output
        }

        // Compatible with the Python no-Pillow fallback: copy a user image as-is,
        // otherwise use the downloaded Twemoji image, otherwise write a gradient PNG.
        for source in moment.images where source.hasPrefix(MomentThumbnailConstants.userImagePrefix) {
            guard let directory = configuration.userImagesDirectory else { continue }
            let sourceURL = directory.appendingPathComponent(source, isDirectory: false)
            guard sourceURL.standardizedFileURL.deletingLastPathComponent() == directory.standardizedFileURL,
                  fileManager.fileExists(atPath: sourceURL.path) else { continue }
            let ext = Self.normalizedExtension(sourceURL.pathExtension.isEmpty ? ".jpg" : "." + sourceURL.pathExtension)
            let output = try thumbnailURL(momentID: moment.id, extension: ext)
            let bytes = try Data(contentsOf: sourceURL)
            try atomicWrite(bytes, to: output)
            return output
        }

        let output = try thumbnailURL(momentID: moment.id, extension: ".png")
        if emoji != nil, let emojiPNG {
            try atomicWrite(emojiPNG, to: output)
            return output
        }
        let png = try ThumbnailPNGEncoder.gradient(colors: gradient)
        try atomicWrite(png, to: output)
        return output
    }

    public func ensureRecentThumbnails(for moments: [MomentThumbnail], limit: Int = 12) async -> [ReadyMomentThumbnail] {
        let boundedLimit = max(0, min(limit, configuration.maximumRecentCount))
        var ready: [ReadyMomentThumbnail] = []
        for moment in moments.prefix(boundedLimit) {
            guard !moment.id.isEmpty else { continue }
            do {
                if let url = try await generateThumbnail(for: moment), fileManager.fileExists(atPath: url.path) {
                    ready.append(ReadyMomentThumbnail(id: moment.id, file: url.lastPathComponent))
                }
            } catch {
                // Match the source helper's per-moment failure isolation: one bad
                // asset must not prevent the rest of the recent list from completing.
                continue
            }
        }
        return ready
    }

    public func ensureRecentThumbnails(from dictionaries: [[String: Any]], limit: Int = 12) async -> [ReadyMomentThumbnail] {
        let moments = dictionaries.prefix(max(0, min(limit, configuration.maximumRecentCount))).map(MomentThumbnail.init(dictionary:))
        return await ensureRecentThumbnails(for: moments, limit: limit)
    }

    public static func emojiCodepoints(_ emoji: String) -> String {
        emoji.unicodeScalars
            .filter { $0.value != 0xFE0F }
            .map { String($0.value, radix: 16) }
            .joined(separator: "-")
    }

    public static func gradient(forMomentID id: String) -> ThumbnailGradient {
        let digest = md5(Data(id.utf8))
        let index = digest.reduce(0) { ($0 * 256 + Int($1)) % MomentThumbnailConstants.gradients.count }
        return MomentThumbnailConstants.gradients[index]
    }

    public static func firstEmoji(in images: [String]) -> String? {
        images.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix(MomentThumbnailConstants.userImagePrefix) }
    }

    private func fetchTwemojiIfNeeded(_ emoji: String?) async throws -> Data? {
        guard let emoji else { return nil }
        let codepoints = Self.emojiCodepoints(emoji)
        guard !codepoints.isEmpty else { return nil }
        let cacheURL = try emojiCacheDirectory().appendingPathComponent(codepoints + ".png", isDirectory: false)
        if fileManager.fileExists(atPath: cacheURL.path) {
            if let data = try? Data(contentsOf: cacheURL), !data.isEmpty, data.count <= configuration.maximumEmojiBytes { return data }
            try? fileManager.removeItem(at: cacheURL)
        }

        guard let url = URL(string: MomentThumbnailConstants.twemojiURLTemplate.replacingOccurrences(of: "{cp}", with: codepoints)) else { return nil }
        do {
            let data = try await httpClient.get(
                url,
                timeout: configuration.requestTimeout,
                headers: ["User-Agent": "Mozilla/5.0 (compatible; zp-moments-thumb/1.0)"]
            )
            guard data.count <= configuration.maximumEmojiBytes, Self.looksLikePNG(data) else { return nil }
            try atomicWrite(data, to: cacheURL)
            return data
        } catch {
            // The Python implementation treats remote emoji retrieval as optional.
            return nil
        }
    }

    private func createDirectory(_ url: URL) throws {
        do { try fileManager.createDirectory(at: url, withIntermediateDirectories: true) }
        catch { throw MomentThumbnailError.filesystem(error.localizedDescription) }
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        do {
            try createDirectory(url.deletingLastPathComponent())
            try data.write(to: url, options: .atomic)
        } catch let error as MomentThumbnailError {
            throw error
        } catch {
            throw MomentThumbnailError.filesystem(error.localizedDescription)
        }
    }

    private static func sanitizedIdentifier(_ identifier: String) -> String {
        // Python's regular expression retains Unicode word characters and hyphens.
        // This implementation preserves letters, numbers, and underscore for common IDs.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let mapped = identifier.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
        return mapped.isEmpty ? "unknown" : mapped
    }

    private static func normalizedExtension(_ value: String) -> String {
        let lower = value.lowercased()
        let withDot = lower.hasPrefix(".") ? lower : "." + lower
        guard withDot.count <= 12,
              withDot.dropFirst().unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else { return ".jpg" }
        return withDot
    }

    private static func looksLikePNG(_ data: Data) -> Bool {
        data.count >= 8 && Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10]
    }

    private static func md5(_ data: Data) -> [UInt8] {
        #if canImport(CryptoKit)
        return Array(Insecure.MD5.hash(data: data))
        #else
        return MD5Fallback.hash(data)
        #endif
    }
}

/// Small MD5 implementation for platforms without CryptoKit, preserving the
/// original Python hashlib.md5 gradient selection without external dependencies.
private enum MD5Fallback {
    private static let shifts: [UInt32] = [7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21]
    private static let constants: [UInt32] = (0..<64).map { UInt32(abs(sin(Double($0 + 1))) * 4_294_967_296.0) }

    static func hash(_ data: Data) -> [UInt8] {
        var message = Array(data)
        let bitLength = UInt64(message.count) &* 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for i in 0..<8 { message.append(UInt8((bitLength >> (8 * i)) & 0xff)) }

        var a0: UInt32 = 0x67452301
        var b0: UInt32 = 0xefcdab89
        var c0: UInt32 = 0x98badcfe
        var d0: UInt32 = 0x10325476
        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 {
                let j = offset + i * 4
                words[i] = UInt32(message[j]) | UInt32(message[j + 1]) << 8 | UInt32(message[j + 2]) << 16 | UInt32(message[j + 3]) << 24
            }
            var a = a0, b = b0, c = c0, d = d0
            for i in 0..<64 {
                let f: UInt32
                let g: Int
                switch i {
                case 0..<16: f = (b & c) | ((~b) & d); g = i
                case 16..<32: f = (d & b) | ((~d) & c); g = (5 * i + 1) % 16
                case 32..<48: f = b ^ c ^ d; g = (3 * i + 5) % 16
                default: f = c ^ (b | (~d)); g = (7 * i) % 16
                }
                let sum = a &+ f &+ constants[i] &+ words[g]
                let rotation = shifts[i]
                let rotated = (sum << rotation) | (sum >> (32 - rotation))
                a = d; d = c; c = b; b = b &+ rotated
            }
            a0 = a0 &+ a; b0 = b0 &+ b; c0 = c0 &+ c; d0 = d0 &+ d
        }
        var output: [UInt8] = []
        for word in [a0, b0, c0, d0] {
            output.append(UInt8(word & 0xff)); output.append(UInt8((word >> 8) & 0xff))
            output.append(UInt8((word >> 16) & 0xff)); output.append(UInt8((word >> 24) & 0xff))
        }
        return output
    }
}
