import SwiftUI
import StickerData
import NukeUI
#if canImport(BackgroundData)
import BackgroundData
#endif
#if STICKER_KEYBOARD_STANDALONE
import CrossProjectComponentsIOS
#endif

/// App-wide sticker-pack discovery sheet. Selecting a pack opens its details.
public struct StickerSearchSheet: View {
    public struct Configuration {
        public var sheet: SheetCustomConfiguration
        public var titleColor: Color
        public var secondaryTextColor: Color
        public var inputBackground: Color
        public var placeholder: String
        public var recentSearchLimit: Int

        public init(
            sheet: SheetCustomConfiguration = .init(height: .fraction(0.90)),
            titleColor: Color = .primary,
            secondaryTextColor: Color = .secondary,
            inputBackground: Color = Color.primary.opacity(0.06),
            placeholder: String = "Search sticker packs",
            recentSearchLimit: Int = 10
        ) {
            self.sheet = sheet
            self.titleColor = titleColor
            self.secondaryTextColor = secondaryTextColor
            self.inputBackground = inputBackground
            self.placeholder = placeholder
            self.recentSearchLimit = min(10, max(1, recentSearchLimit))
        }
    }

    @Binding private var isPresented: Bool
    private let configuration: Configuration
    private let onSearch: (String) -> Void
    private let packs: [StickerPack]
    private let stickers: [Sticker]
    private let assets: [String: StickerAsset]
    private let installedPackIDs: Set<String>
    private let installedPackVersions: [String: String]
    private let likedPackIDs: Set<String>
    private let onInstallPack: (StickerPack) -> Void
    private let onDeletePack: (StickerPack) -> Void
    private let onLikePack: (StickerPack, Bool) -> Void
    @State private var query = ""
    @State private var randomizedPacks: [StickerPack] = []
    @State private var selectedPackID: String?
    @AppStorage("CrossProjectComponents.StickerSearchSheet.recentSearches") private var recentSearchesStorage = "[]"

    private var recentSearches: [String] {
        guard let data = recentSearchesStorage.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }

    private var selectedPack: StickerPack? { packs.first { $0.id == selectedPackID } }

    public init(
        isPresented: Binding<Bool>,
        configuration: Configuration = .init(),
        packs: [StickerPack] = [],
        stickers: [Sticker] = [],
        assets: [String: StickerAsset] = [:],
        installedPackIDs: Set<String> = [],
        installedPackVersions: [String: String] = [:],
        likedPackIDs: Set<String> = [],
        onInstallPack: @escaping (StickerPack) -> Void = { _ in },
        onDeletePack: @escaping (StickerPack) -> Void = { _ in },
        onLikePack: @escaping (StickerPack, Bool) -> Void = { _, _ in },
        onSearch: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.configuration = configuration
        self.packs = packs
        self.stickers = stickers
        self.assets = assets
        self.installedPackIDs = installedPackIDs
        self.installedPackVersions = installedPackVersions
        self.likedPackIDs = likedPackIDs
        self.onInstallPack = onInstallPack
        self.onDeletePack = onDeletePack
        self.onLikePack = onLikePack
        self.onSearch = onSearch
    }

    public var body: some View {
        ZStack {
            Color.clear
            if isPresented {
                SheetCustom(isPresented: $isPresented, configuration: configuration.sheet) {
                    searchContent
                }
                .onAppear { shufflePacks() }
                .onChange(of: isPresented) { _, presented in
                    if presented { shufflePacks() }
                }
            }
        }
        // Fill the proposed overlay area so the sheet can size against the host.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            if let pack = selectedPack {
                packDetail(pack)
            } else {
                packCatalogue
            }
            if selectedPack == nil {
                VStack(alignment: .leading, spacing: 8) {
                    if !recentSearches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentSearches.prefix(configuration.recentSearchLimit), id: \.self) { term in
                                    CapsuleButton(
                                        term,
                                        background: configuration.inputBackground,
                                        foreground: configuration.titleColor,
                                        padding: EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12),
                                        font: .system(size: 13, weight: .medium)
                                    ) {
                                        query = term
                                        selectedPackID = nil
                                        onSearch(term)
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }

                    HStack(spacing: 10) {
                    TextFieldCustom(
                        text: $query,
                        placeholder: configuration.placeholder,
                        font: .system(size: 15),
                        foreground: configuration.titleColor,
                        background: AnyView(Color.clear),
                        shape: .roundedRectangle(12),
                        submitLabel: .search,
                        minHeight: 40,
                        onSubmit: { submit(query) }
                    )
                    .frame(height: 40)
                    .background(configuration.inputBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button { submit(query) } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(configuration.titleColor)
                            .frame(width: 40, height: 40)
                            .background(configuration.inputBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search sticker packs")
                }
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var packCatalogue: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPacks) { pack in
                    Button { selectedPackID = pack.id } label: {
                        HStack(spacing: 14) {
                            PackCover(pack: pack, stickers: stickers, assets: assets)
                                .frame(width: 88, height: 88)
                                .background(configuration.inputBackground, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(pack.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(configuration.titleColor)
                                    Spacer(minLength: 4)
                                    if installedPackIDs.contains(pack.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                    }
                                }
                                if !pack.shortDescription.isEmpty {
                                    Text(pack.shortDescription).font(.system(size: 13)).foregroundStyle(configuration.secondaryTextColor)
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                }
                                if !pack.tags.isEmpty {
                                    Text(pack.tags.map { "#\($0)" }.joined(separator: "  "))
                                        .font(.system(size: 11, weight: .medium)).foregroundStyle(configuration.secondaryTextColor).lineLimit(1)
                                }
                            }
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(configuration.inputBackground.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .overlay {
            if filteredPacks.isEmpty {
                ContentUnavailableView("No sticker packs", systemImage: "square.grid.3x3", description: Text("Try another search term."))
            }
        }
    }

    private var filteredPacks: [StickerPack] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return randomizedPacks }
        return randomizedPacks.filter { pack in
            pack.name.localizedCaseInsensitiveContains(term)
                || pack.shortDescription.localizedCaseInsensitiveContains(term)
                || pack.tags.contains { $0.localizedCaseInsensitiveContains(term) }
                || pack.publisher?.localizedCaseInsensitiveContains(term) == true
        }
    }

    private func packDetail(_ pack: StickerPack) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { selectedPackID = nil } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to sticker packs")

                Text(pack.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(configuration.titleColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Stickers · \(packStickers(pack).count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(configuration.secondaryTextColor)
                        Spacer(minLength: 8)
                        if let author = pack.authorNickname ?? pack.publisher, !author.isEmpty {
                            Text("by \(author)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(configuration.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(packStickers(pack)) { sticker in
                            if let asset = assets[sticker.assetID] {
                                StickerThumbnail(asset: asset).aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .padding(.bottom, 72)
            }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    HStack(spacing: 8) {
                        packActions(pack)
                        Spacer(minLength: 0)
                        packLikeButton(pack)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: geometry.size.width * 0.9)
                    .background {
                        ContainerStyle(height: 44, style: .capsule(width: 1))
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .frame(width: geometry.size.width, height: 54)
                    .padding(.bottom, 10)
                }
                .frame(height: 64)
            }
        }
    }

    @ViewBuilder
    private func packActions(_ pack: StickerPack) -> some View {
        let isInstalled = installedPackIDs.contains(pack.id)
        let needsUpdate = isInstalled && installedPackVersions[pack.id].map { $0 != pack.version } == true

        HStack(spacing: 5) {
            Button {
                guard !isInstalled || needsUpdate else { return }
                onInstallPack(pack)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: needsUpdate ? "arrow.clockwise" : (isInstalled ? "checkmark" : "arrow.down.to.line"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(needsUpdate ? "Update" : (isInstalled ? "Installed" : "Install"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(isInstalled && !needsUpdate ? configuration.titleColor : Color.white)
                .padding(.horizontal, 11)
                .frame(minHeight: 30)
                .background {
                    Capsule()
                        .fill(isInstalled && !needsUpdate ? Color.primary.opacity(0.07) : Color.accentColor.opacity(0.97))
                }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .transaction { $0.animation = nil }
            .disabled(isInstalled && !needsUpdate)
            .disabled(isInstalled && !needsUpdate)
            .accessibilityLabel(needsUpdate ? "Update pack" : (isInstalled ? "Installed" : "Install pack"))

            if isInstalled {
                Button(role: .destructive) { onDeletePack(pack) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Delete pack")
            }

        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func packLikeButton(_ pack: StickerPack) -> some View {
        Button { onLikePack(pack, !likedPackIDs.contains(pack.id)) } label: {
            Image(systemName: likedPackIDs.contains(pack.id) ? "heart.fill" : "heart")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(likedPackIDs.contains(pack.id) ? .pink : configuration.titleColor)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(likedPackIDs.contains(pack.id) ? "Unlike pack" : "Like pack")
    }

    private func packStickers(_ pack: StickerPack) -> [Sticker] {
        let byID = Dictionary(uniqueKeysWithValues: stickers.map { ($0.id, $0) })
        return pack.stickerIDs.compactMap { byID[$0] }
    }

    private func shufflePacks() { randomizedPacks = packs.shuffled() }

    private func submit(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var updated = recentSearches.filter { $0.localizedCaseInsensitiveCompare(value) != .orderedSame }
        updated.insert(value, at: 0)
        if updated.count > configuration.recentSearchLimit { updated = Array(updated.prefix(configuration.recentSearchLimit)) }
        if let data = try? JSONEncoder().encode(updated), let encoded = String(data: data, encoding: .utf8) {
            recentSearchesStorage = encoded
        }
        query = value
        selectedPackID = nil
        onSearch(value)
    }
}

private struct PackCover: View {
    let pack: StickerPack
    let stickers: [Sticker]
    let assets: [String: StickerAsset]

    var body: some View {
        Group {
            if let coverID = pack.coverAssetID, let asset = assets[coverID] {
                StickerThumbnail(asset: asset)
            } else if let sticker = stickers.first(where: { $0.packID == pack.id }), let asset = assets[sticker.assetID] {
                StickerThumbnail(asset: asset)
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 28)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StickerThumbnail: View {
    let asset: StickerAsset

    var body: some View {
        LazyImage(url: asset.thumbnailLocation ?? asset.originalLocation) { state in
            if let image = state.image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else if state.error != nil {
                Image(systemName: "photo").font(.system(size: 22)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay { ProgressView().controlSize(.small) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Rectangle())
    }
}
