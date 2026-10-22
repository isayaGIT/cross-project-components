import SwiftUI
import NukeUI
import StickerData

/// A reusable image-sticker keyboard. The host owns the data source, favorites,
/// recent-use persistence, message draft, focus, and placement of this panel.
public struct StickerKeyboard: View {
    public struct Configuration: Equatable {
        public var height: CGFloat
        public var columns: Int
        public var stickerSize: CGFloat
        public var categoryBarHeight: CGFloat
        public var spacing: CGFloat
        public var topBorderColor: Color
        public var topBorderHeight: CGFloat
        public var categoryDividerColor: Color
        public var categoryDividerHeight: CGFloat
        public var categoryBarBackground: Color
        public var selectedCategoryBackground: Color
        public var selectedCategoryBorderColor: Color
        public var selectedCategoryBorderWidth: CGFloat
        public var emojiBackground: Color

        public init(
            height: CGFloat = 286,
            columns: Int = 5,
            stickerSize: CGFloat = 58,
            categoryBarHeight: CGFloat = 48,
            spacing: CGFloat = 3,
            topBorderColor: Color = Color.primary.opacity(0.08),
            topBorderHeight: CGFloat = 1,
            categoryDividerColor: Color = Color.primary.opacity(0.08),
            categoryDividerHeight: CGFloat = 1,
            categoryBarBackground: Color = .clear,
            selectedCategoryBackground: Color = Color.primary.opacity(0.09),
            selectedCategoryBorderColor: Color = .clear,
            selectedCategoryBorderWidth: CGFloat = 0,
            emojiBackground: Color = .clear
        ) {
            self.height = max(180, height)
            self.columns = min(10, max(3, columns))
            self.stickerSize = min(100, max(36, stickerSize))
            self.categoryBarHeight = max(40, categoryBarHeight)
            self.spacing = max(0, spacing)
            self.topBorderColor = topBorderColor
            self.topBorderHeight = max(0, topBorderHeight)
            self.categoryDividerColor = categoryDividerColor
            self.categoryDividerHeight = max(0, categoryDividerHeight)
            self.categoryBarBackground = categoryBarBackground
            self.selectedCategoryBackground = selectedCategoryBackground
            self.selectedCategoryBorderColor = selectedCategoryBorderColor
            self.selectedCategoryBorderWidth = max(0, selectedCategoryBorderWidth)
            self.emojiBackground = emojiBackground
        }

        public static let standard = Configuration()
    }

    public static let defaultHeight: CGFloat = Configuration.standard.height

    private enum Section: Hashable { case search, emoji, defaultPack, favorites, pack(String) }
    private struct CategoryItem: Identifiable {
        let id: Section
        let title: String
        let symbol: String
        let cover: URL?
    }

    public let configuration: Configuration
    private let stickers: [Sticker]
    private let packs: [StickerPack]
    private let assets: [String: StickerAsset]
    private let userConfiguration: UserStickerConfiguration
    private let defaultPackID: String?
    private let emojis: [String]
    private let onEmojiSelect: (String) -> Void
    private let onSelect: (Sticker) -> Void
    private let legacyOnSelect: ((String) -> Void)?
    private let onSearch: ((String) -> Void)?
    private let onSearchRequested: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: Section = .emoji

    /// Creates the complete sticker keyboard, including built-in emoji, favorites,
    /// search entry, and any selected image sticker packs.
    public init(
        stickers: [Sticker],
        packs: [StickerPack],
        assets: [StickerAsset],
        userConfiguration: UserStickerConfiguration = .init(),
        defaultPackID: String? = nil,
        emojis: [String] = ["😀", "😂", "🥰", "😍", "😊", "🥹", "😭", "😎", "🤔", "👍", "👎", "👏", "🙏", "❤️", "💕", "🔥", "🎉", "✨", "🌹", "🐱", "🐶", "🐻", "🍕", "☕", "🚀", "💯", "✅", "❌", "🥳", "🤗"],
        configuration: Configuration = .standard,
        onSearch: ((String) -> Void)? = nil,
        onSearchRequested: @escaping () -> Void,
        onEmojiSelect: @escaping (String) -> Void,
        onSelect: @escaping (Sticker) -> Void
    ) {
        self.configuration = configuration
        self.stickers = stickers
        self.packs = packs
        self.assets = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.userConfiguration = userConfiguration
        self.defaultPackID = defaultPackID ?? packs.first?.id
        self.emojis = emojis
        self.onEmojiSelect = onEmojiSelect
        self.onSearch = onSearch
        self.onSearchRequested = onSearchRequested
        self.onSelect = onSelect
        self.legacyOnSelect = nil
    }

    /// Compatibility initializer for hosts still using the old Unicode picker API.
    /// New integrations should use the complete initializer above so the keyboard
    /// owns the unified emoji, search, favorites, and sticker-pack experience.
    @available(*, deprecated, message: "Use the complete initializer with onEmojiSelect and onSelect")
    public init(configuration: Configuration = .standard, onSelect: @escaping (String) -> Void) {
        self.configuration = configuration
        self.stickers = []
        self.packs = []
        self.assets = [:]
        self.userConfiguration = .init()
        self.defaultPackID = nil
        self.emojis = []
        self.onEmojiSelect = onSelect
        self.onSearch = nil
        self.onSearchRequested = nil
        self.onSelect = { _ in }
        self.legacyOnSelect = onSelect
    }

    private var orderedPacks: [StickerPack] {
        let byID = Dictionary(packs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return userConfiguration.selectedPackIDs.compactMap { byID[$0] }
    }

    private var categories: [CategoryItem] {
        var result = [
            CategoryItem(id: .search, title: "Search stickers", symbol: "magnifyingglass", cover: nil),
            CategoryItem(id: .emoji, title: "Emoji", symbol: "face.smiling", cover: nil),
            CategoryItem(id: .favorites, title: "Favorites", symbol: "heart", cover: nil)
        ]
        result += orderedPacks.map { pack in
            CategoryItem(id: .pack(pack.id), title: pack.name, symbol: "square.stack.3d.up", cover: pack.coverAssetID.flatMap { assets[$0]?.thumbnailLocation ?? assets[$0]?.originalLocation })
        }
        return result
    }

    private var defaultPackCover: URL? {
        guard let id = defaultPackID, let pack = packs.first(where: { $0.id == id }), let coverID = pack.coverAssetID else { return nil }
        return assets[coverID]?.thumbnailLocation ?? assets[coverID]?.originalLocation
    }

    private var displayedStickers: [Sticker] {
        let source: [Sticker]
        switch selectedSection {
        case .search, .emoji:
            source = []
        case .defaultPack:
            guard let defaultPackID else { return [] }
            source = stickers.filter { $0.packID == defaultPackID }
        case .favorites:
            let favorites = Set(userConfiguration.favoriteStickerIDs)
            source = userConfiguration.favoriteStickerIDs.compactMap { id in stickers.first(where: { $0.id == id }) }.filter { favorites.contains($0.id) }
        case .pack(let packID):
            source = stickers.filter { $0.packID == packID }
        }
        return source
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = gridLayout(for: geometry.size.width)
            VStack(spacing: 0) {
                categoryBar
                ScrollView {
                    if selectedSection == .emoji {
                        emojiGrid(onSelect: onEmojiSelect, columns: layout.columns)
                    } else if let legacyOnSelect, stickers.isEmpty {
                        legacyEmojiGrid(onSelect: legacyOnSelect, columns: layout.columns)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.stickerSize), spacing: configuration.spacing), count: layout.columns), spacing: configuration.spacing) {
                            ForEach(displayedStickers) { sticker in
                                if let asset = assets[sticker.assetID] {
                                    Button { onSelect(sticker) } label: {
                                        StickerThumbnail(asset: asset, size: layout.stickerSize)
                                            .frame(width: layout.stickerSize, height: layout.stickerSize)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(sticker.name ?? "Sticker")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                    }
                }
                .background(selectedSection == .emoji ? configuration.emojiBackground : Color.clear)
                .overlay {
                    if displayedStickers.isEmpty && selectedSection != .emoji && legacyOnSelect == nil {
                        VStack(spacing: 8) {
                            Image(systemName: selectedSection == .favorites ? "heart" : "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                            Text(selectedSection == .favorites ? "No favorites yet" : "No stickers")
                                .font(.system(size: 14, weight: .medium))
                            Text(selectedSection == .search ? "Try another search." : "Add a sticker pack to get started.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(.regularMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(configuration.topBorderColor)
                    .frame(height: configuration.topBorderHeight)
            }
        }
        .frame(height: configuration.height)
    }

    /// Keeps sticker size proportional to the reference width while making the
    /// horizontal inter-item gap match the configured vertical grid spacing.
    /// Wider containers gain columns only when stickers would grow beyond 120%
    /// of their reference size, which keeps iPad landscape from producing huge stickers.
    private func gridLayout(for containerWidth: CGFloat) -> (columns: Int, stickerSize: CGFloat) {
        let horizontalInset: CGFloat = 12
        let availableWidth = max(0, containerWidth - horizontalInset)
        let referenceSize = configuration.stickerSize
        let maximumSize = referenceSize * 1.2
        var columns = configuration.columns
        var size = (availableWidth - CGFloat(columns - 1) * configuration.spacing) / CGFloat(columns)

        while size > maximumSize && columns < 10 {
            columns += 1
            size = (availableWidth - CGFloat(columns - 1) * configuration.spacing) / CGFloat(columns)
        }

        // On narrow screens, preserve the reference sticker size by allowing
        // the grid to scroll horizontally only as a last resort is undesirable;
        // fit to the available width instead.
        size = min(size, maximumSize)
        return (columns, max(1, size))
    }

    @ViewBuilder private func emojiGrid(onSelect: @escaping (String) -> Void, columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: configuration.spacing), count: columns), spacing: configuration.spacing) {
            ForEach(emojis, id: \.self) { emoji in
                Button { onSelect(emoji) } label: {
                    Text(emoji).font(.system(size: 27)).frame(maxWidth: .infinity).frame(height: 38).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 6).padding(.vertical, 6)
    }

    @ViewBuilder private func legacyEmojiGrid(onSelect: @escaping (String) -> Void, columns: Int) -> some View {
        emojiGrid(onSelect: onSelect, columns: columns)
    }

    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(categories) { category in
                        Button {
                            if category.id == .search {
                                onSearchRequested?()
                                return
                            }
                            withAnimation(.easeInOut(duration: 0.16)) { selectedSection = category.id }
                            withAnimation(.easeInOut(duration: 0.18)) { proxy.scrollTo(category.id, anchor: .center) }
                        } label: {
                            categoryIcon(category)
                                .frame(width: 42, height: configuration.categoryBarHeight - 4)
                                .background(
                                    selectedSection == category.id ? configuration.selectedCategoryBackground : .clear,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            selectedSection == category.id ? configuration.selectedCategoryBorderColor : .clear,
                                            lineWidth: configuration.selectedCategoryBorderWidth
                                        )
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(category.title)
                        .accessibilityAddTraits(selectedSection == category.id ? .isSelected : [])
                        .id(category.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .scrollIndicators(.hidden)
            .frame(height: configuration.categoryBarHeight)
            .background(configuration.categoryBarBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(configuration.categoryDividerColor)
                    .frame(height: configuration.categoryDividerHeight)
            }
        }
    }

    @ViewBuilder private func categoryIcon(_ category: CategoryItem) -> some View {
        if let url = category.cover {
            LazyImage(url: url) { state in
                if let image = state.image { image.resizable().aspectRatio(contentMode: .fit) }
                else { Image(systemName: category.symbol).foregroundStyle(.secondary) }
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: category.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(selectedSection == category.id ? Color.primary : Color.primary.opacity(colorScheme == .dark ? 0.72 : 0.62))
        }
    }
}

private struct StickerThumbnail: View {
    let asset: StickerAsset
    let size: CGFloat

    private var url: URL { asset.thumbnailLocation ?? asset.originalLocation }

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else if state.error != nil {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay { ProgressView().controlSize(.small) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Rectangle())
    }
}
