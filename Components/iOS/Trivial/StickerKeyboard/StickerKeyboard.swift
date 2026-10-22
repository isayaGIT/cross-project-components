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

        public init(height: CGFloat = 286, columns: Int = 5, stickerSize: CGFloat = 58, categoryBarHeight: CGFloat = 48) {
            self.height = max(180, height)
            self.columns = min(10, max(3, columns))
            self.stickerSize = min(100, max(36, stickerSize))
            self.categoryBarHeight = max(40, categoryBarHeight)
        }

        public static let standard = Configuration()
    }

    public static let defaultHeight: CGFloat = Configuration.standard.height

    private enum Section: Hashable { case search, defaultPack, favorites, pack(String) }
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
    private let onSelect: (Sticker) -> Void
    private let legacyOnSelect: ((String) -> Void)?
    private let onSearch: ((String) -> Void)?
    private let onSearchRequested: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: Section = .defaultPack

    /// Creates a data-driven image sticker keyboard.
    public init(
        stickers: [Sticker],
        packs: [StickerPack],
        assets: [StickerAsset],
        userConfiguration: UserStickerConfiguration = .init(),
        defaultPackID: String? = nil,
        configuration: Configuration = .standard,
        onSearch: ((String) -> Void)? = nil,
        onSearchRequested: @escaping () -> Void,
        onSelect: @escaping (Sticker) -> Void
    ) {
        self.configuration = configuration
        self.stickers = stickers
        self.packs = packs
        self.assets = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.userConfiguration = userConfiguration
        self.defaultPackID = defaultPackID ?? packs.first?.id
        self.onSearch = onSearch
        self.onSearchRequested = onSearchRequested
        self.onSelect = onSelect
        self.legacyOnSelect = nil
    }

    /// Compatibility initializer for hosts still using the old Unicode picker API.
    /// Prefer the data-driven initializer for actual image stickers.
    public init(configuration: Configuration = .standard, onSelect: @escaping (String) -> Void) {
        self.configuration = configuration
        self.stickers = []
        self.packs = []
        self.assets = [:]
        self.userConfiguration = .init()
        self.defaultPackID = nil
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
            CategoryItem(id: .defaultPack, title: "Built-in emoji", symbol: "face.smiling", cover: nil),
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
        case .search:
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
        VStack(spacing: 0) {
            categoryBar
            ScrollView {
                if let legacyOnSelect, stickers.isEmpty {
                    legacyEmojiGrid(onSelect: legacyOnSelect)
                } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: configuration.columns), spacing: 6) {
                    ForEach(displayedStickers) { sticker in
                        if let asset = assets[sticker.assetID] {
                            Button { onSelect(sticker) } label: {
                                StickerThumbnail(asset: asset, size: configuration.stickerSize)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: configuration.stickerSize + 8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(sticker.name ?? "Sticker")
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                }
            }
            .overlay {
                if displayedStickers.isEmpty && legacyOnSelect == nil {
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
        .frame(height: configuration.height)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)).frame(height: 1) }
    }

    @ViewBuilder private func legacyEmojiGrid(onSelect: @escaping (String) -> Void) -> some View {
        let emojis = ["😀", "😂", "🥰", "😍", "😊", "🥹", "😭", "😎", "🤔", "👍", "👎", "👏", "🙏", "❤️", "💕", "🔥", "🎉", "✨", "🌹", "🐱", "🐶", "🐻", "🍕", "☕", "🚀", "💯", "✅", "❌", "🥳", "🤗"]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: configuration.columns), spacing: 4) {
            ForEach(emojis, id: \.self) { emoji in
                Button { onSelect(emoji) } label: {
                    Text(emoji).font(.system(size: 27)).frame(maxWidth: .infinity).frame(height: 38).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 8).padding(.vertical, 7)
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
                                .background(selectedSection == category.id ? Color.primary.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
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
                .foregroundStyle(selectedSection == category.id ? Color.primary : Color.secondary)
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
