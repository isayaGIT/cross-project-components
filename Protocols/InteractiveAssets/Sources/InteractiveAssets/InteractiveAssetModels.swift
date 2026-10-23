import Foundation

/// Versioned, language-neutral contract for downloadable interactive content.
/// JSON field names intentionally use lower camelCase to match the JSON Schemas.
public enum InteractiveAssetsProtocol {
    public static let currentVersion = "1.0"
}

/// A downloadable file. `sha256` is the lowercase hexadecimal SHA-256 digest of the exact bytes.
public struct AssetFile: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let fileName: String
    public let mediaType: String
    public let byteCount: Int64
    public let sha256: String
    public var role: String?

    public init(id: String, fileName: String, mediaType: String, byteCount: Int64, sha256: String, role: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.mediaType = mediaType
        self.byteCount = byteCount
        self.sha256 = sha256.lowercased()
        self.role = role
    }
}

/// Bundle-level manifest. Asset IDs are stable opaque identifiers, not paths.
public struct InteractiveAssetManifest: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var contentID: String
    public var contentType: InteractiveContentType
    public var contentVersion: String
    public var minimumClientVersion: String?
    public var files: [AssetFile]
    public var metadataFileID: String?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, contentID: String,
                contentType: InteractiveContentType, contentVersion: String,
                minimumClientVersion: String? = nil, files: [AssetFile], metadataFileID: String? = nil) {
        self.protocolVersion = protocolVersion
        self.contentID = contentID
        self.contentType = contentType
        self.contentVersion = contentVersion
        self.minimumClientVersion = minimumClientVersion
        self.files = files
        self.metadataFileID = metadataFileID
    }
}

public enum InteractiveContentType: String, Codable, CaseIterable, Sendable {
    case stickerPack = "sticker-pack"
    case stickerLibrary = "sticker-library"
    case sticker
    case animatedMessageBubble = "animated-message-bubble"
    case fullscreenAnimation = "fullscreen-animation"
}

/// Reference to a file declared by the enclosing manifest. Never interpret this as an arbitrary URL/path.
public struct AssetReference: Codable, Hashable, Sendable {
    public var assetID: String
    public var role: String?

    public init(assetID: String, role: String? = nil) {
        self.assetID = assetID
        self.role = role
    }
}

/// Discoverable index of published packs; mirrors the existing `StickerLibrary` concept.
public struct StickerLibraryDocument: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var id: String
    public var name: String
    public var version: String
    public var packIDs: [String]
    public var publisher: String?
    public var updatedAt: String?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, id: String, name: String,
                version: String = "1", packIDs: [String], publisher: String? = nil, updatedAt: String? = nil) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.name = name
        self.version = version
        self.packIDs = packIDs
        self.publisher = publisher
        self.updatedAt = updatedAt
    }
}

public struct StickerPackDocument: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var id: String
    public var name: String
    public var shortDescription: String
    public var tags: [String]
    public var cover: AssetReference?
    public var version: String
    public var stickers: [StickerEntry]
    public var publisher: String?
    public var authorNickname: String?
    public var authorID: String?
    public var updatedAt: String?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, id: String, name: String,
                shortDescription: String = "", tags: [String] = [], cover: AssetReference? = nil,
                version: String = "1", stickers: [StickerEntry], publisher: String? = nil,
                authorNickname: String? = nil, authorID: String? = nil, updatedAt: String? = nil) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.tags = tags
        self.cover = cover
        self.version = version
        self.stickers = stickers
        self.publisher = publisher
        self.authorNickname = authorNickname
        self.authorID = authorID
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey { case protocolVersion, id, name, shortDescription, tags, cover, version, stickers, publisher, authorNickname, authorID, updatedAt }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try values.decode(String.self, forKey: .protocolVersion)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        shortDescription = try values.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        cover = try values.decodeIfPresent(AssetReference.self, forKey: .cover)
        version = try values.decode(String.self, forKey: .version)
        stickers = try values.decode([StickerEntry].self, forKey: .stickers)
        publisher = try values.decodeIfPresent(String.self, forKey: .publisher)
        authorNickname = try values.decodeIfPresent(String.self, forKey: .authorNickname)
        authorID = try values.decodeIfPresent(String.self, forKey: .authorID)
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

public struct StickerEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String?
    public var tags: [String]
    public var media: AssetReference
    public var thumbnail: AssetReference?
    public var parameters: AssetReference?

    public init(id: String, name: String? = nil, tags: [String] = [], media: AssetReference,
                thumbnail: AssetReference? = nil, parameters: AssetReference? = nil) {
        self.id = id
        self.name = name
        self.tags = tags
        self.media = media
        self.thumbnail = thumbnail
        self.parameters = parameters
    }

    private enum CodingKeys: String, CodingKey { case id, name, tags, media, thumbnail, parameters }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        media = try values.decode(AssetReference.self, forKey: .media)
        thumbnail = try values.decodeIfPresent(AssetReference.self, forKey: .thumbnail)
        parameters = try values.decodeIfPresent(AssetReference.self, forKey: .parameters)
    }
}

public struct StickerDocument: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var id: String
    public var name: String?
    public var tags: [String]
    public var media: AssetReference
    public var thumbnail: AssetReference?
    public var parameters: AssetReference?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, id: String, name: String? = nil,
                tags: [String] = [], media: AssetReference, thumbnail: AssetReference? = nil,
                parameters: AssetReference? = nil) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.name = name
        self.tags = tags
        self.media = media
        self.thumbnail = thumbnail
        self.parameters = parameters
    }

    private enum CodingKeys: String, CodingKey { case protocolVersion, id, name, tags, media, thumbnail, parameters }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try values.decode(String.self, forKey: .protocolVersion)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        media = try values.decode(AssetReference.self, forKey: .media)
        thumbnail = try values.decodeIfPresent(AssetReference.self, forKey: .thumbnail)
        parameters = try values.decodeIfPresent(AssetReference.self, forKey: .parameters)
    }
}

public struct AnimatedMessageBubbleDocument: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var id: String
    public var version: String
    public var renderer: BubbleRenderer
    public var background: AssetReference?
    public var decorations: [BubbleDecoration]
    public var layout: BubbleLayout
    public var parameters: AssetReference?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, id: String, version: String = "1",
                renderer: BubbleRenderer, background: AssetReference? = nil, decorations: [BubbleDecoration] = [],
                layout: BubbleLayout = BubbleLayout(), parameters: AssetReference? = nil) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.version = version
        self.renderer = renderer
        self.background = background
        self.decorations = decorations
        self.layout = layout
        self.parameters = parameters
    }
}

public enum BubbleRenderer: String, Codable, CaseIterable, Sendable {
    case gif
    case lottie
    case ninePatchFrames = "nine-patch-frames"
}

public enum DecorationPlacement: String, Codable, CaseIterable, Sendable {
    case inside
    case overlapping
}

public enum AnimationLoop: String, Codable, CaseIterable, Sendable {
    case once
    case loop
    case repeatCount = "repeat-count"
}

public struct BubbleDecoration: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var asset: AssetReference
    public var placement: DecorationPlacement
    public var width: Double
    public var height: Double
    public var alignment: String
    public var offsetX: Double
    public var offsetY: Double
    public var loop: AnimationLoop
    public var repeatCount: Int?

    public init(id: String, asset: AssetReference, placement: DecorationPlacement = .overlapping,
                width: Double = 44, height: Double = 44, alignment: String = "topTrailing",
                offsetX: Double = 0, offsetY: Double = 0, loop: AnimationLoop = .loop, repeatCount: Int? = nil) {
        self.id = id
        self.asset = asset
        self.placement = placement
        self.width = width
        self.height = height
        self.alignment = alignment
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.loop = loop
        self.repeatCount = repeatCount
    }
}

/// Dimensions are logical points; all insets are non-negative logical points.
public struct BubbleLayout: Codable, Hashable, Sendable {
    public var cornerRadius: Double
    public var paddingTop: Double
    public var paddingLeading: Double
    public var paddingBottom: Double
    public var paddingTrailing: Double

    public init(cornerRadius: Double = 16, paddingTop: Double = 12, paddingLeading: Double = 14,
                paddingBottom: Double = 12, paddingTrailing: Double = 14) {
        self.cornerRadius = cornerRadius
        self.paddingTop = paddingTop
        self.paddingLeading = paddingLeading
        self.paddingBottom = paddingBottom
        self.paddingTrailing = paddingTrailing
    }
}

public struct FullscreenAnimationDocument: Codable, Hashable, Sendable {
    public var protocolVersion: String
    public var id: String
    public var version: String
    public var renderer: FullscreenRenderer
    public var media: AssetReference
    public var durationMs: Int?
    public var loop: AnimationLoop
    public var trigger: String
    public var contentMode: String
    public var dismissible: Bool
    public var audio: AssetReference?
    public var parameters: AssetReference?

    public init(protocolVersion: String = InteractiveAssetsProtocol.currentVersion, id: String, version: String = "1",
                renderer: FullscreenRenderer, media: AssetReference, durationMs: Int? = nil,
                loop: AnimationLoop = .once, trigger: String = "explicit", contentMode: String = "aspectFit",
                dismissible: Bool = true, audio: AssetReference? = nil, parameters: AssetReference? = nil) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.version = version
        self.renderer = renderer
        self.media = media
        self.durationMs = durationMs
        self.loop = loop
        self.trigger = trigger
        self.contentMode = contentMode
        self.dismissible = dismissible
        self.audio = audio
        self.parameters = parameters
    }
}

public enum FullscreenRenderer: String, Codable, CaseIterable, Sendable {
    case gif
    case lottie
    case video
    case imageSequence = "image-sequence"
}

/// NinePatchStudio export compatibility model (`ninepatch-studio/animation-v1`).
public struct NinePatchAnimationExport: Codable, Hashable, Sendable {
    public var format: String
    public var sourceFileName: String
    public var sourceWidth: Int
    public var sourceHeight: Int
    public var frameCount: Int
    public var totalDuration: Double
    public var frames: [NinePatchFrame]
    public var stretchInsets: SliceInsets
    public var contentInsets: SliceInsets
    public var integrationNote: String?

    public init(format: String = "ninepatch-studio/animation-v1", sourceFileName: String,
                sourceWidth: Int, sourceHeight: Int, frameCount: Int, totalDuration: Double,
                frames: [NinePatchFrame], stretchInsets: SliceInsets, contentInsets: SliceInsets, integrationNote: String? = nil) {
        self.format = format
        self.sourceFileName = sourceFileName
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.frameCount = frameCount
        self.totalDuration = totalDuration
        self.frames = frames
        self.stretchInsets = stretchInsets
        self.contentInsets = contentInsets
        self.integrationNote = integrationNote
    }
}

public struct NinePatchFrame: Codable, Hashable, Sendable {
    public var fileName: String
    public var duration: Double
    public init(fileName: String, duration: Double) { self.fileName = fileName; self.duration = duration }
}

public struct SliceInsets: Codable, Hashable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double
    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
}
