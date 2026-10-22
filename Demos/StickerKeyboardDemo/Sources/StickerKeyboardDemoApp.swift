import StickerData
import SwiftUI

@main
struct StickerKeyboardDemoApp: App {
    var body: some Scene {
        WindowGroup { StickerKeyboardDemoView() }
    }
}

private struct StickerKeyboardDemoView: View {
    @State private var draft = ""
    @State private var selectedStickerName = "None"
    @State private var lastSearch = "None"
    @State private var searchPresented = false
    @State private var installedPackIDs: [String] = ["demo-cute"]
    @State private var installedPackVersions: [String: String] = ["demo-cute": "1"]
    @State private var likedPackIDs: Set<String> = ["demo-food"]

    private let packID = "demo-cute"
    private let stickers: [Sticker] = (0..<12).map { index in
        Sticker(id: "cute-\(index)", packID: "demo-cute", assetID: "cute-\(index)", name: ["Happy", "Sunny", "Nature", "Coffee", "Ocean", "Flower", "Cat", "Dog", "Sky", "Leaf", "Berry", "Cloud"][index], tags: ["demo", "cute"])
    } + (0..<8).map { index in
        Sticker(id: "demo-food-\(index)", packID: "demo-food", assetID: "food-\(index)", name: "Food \(index + 1)", tags: ["food"])
    }

    private let packs: [StickerPack] = [
        StickerPack(id: "demo-cute", name: "Cute Animals", shortDescription: "A little collection of cute animal moments.", tags: ["cute", "animals", "happy"], coverAssetID: "cute-0", stickerIDs: (0..<12).map { "cute-\($0)" }, authorNickname: "Kori", authorUUID: "demo-author-cute"),
        StickerPack(id: "demo-food", name: "Food Mood", shortDescription: "Food for every mood and craving.", tags: ["food", "daily", "fun"], coverAssetID: "food-0", stickerIDs: (0..<8).map { "demo-food-\($0)" }, authorNickname: "Momo", authorUUID: "demo-author-food")
    ]

    private var assets: [StickerAsset] {
        let cuteURLs = [
            "https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1517849845537-4d257902454a?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1497250681960-ef046c08a56e?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=240&h=240&fit=crop"
        ]
        let foodURLs = [
            "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=240&h=240&fit=crop",
            "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=240&h=240&fit=crop"
        ]
        let cute = cuteURLs.enumerated().map { index, string in
            StickerAsset(id: "cute-\(index)", originalLocation: URL(string: string)!, thumbnailLocation: URL(string: string)!, mediaType: .jpeg, pixelWidth: 240, pixelHeight: 240)
        }
        let food = foodURLs.enumerated().map { index, string in
            StickerAsset(id: "food-\(index)", originalLocation: URL(string: string)!, thumbnailLocation: URL(string: string)!, mediaType: .jpeg, pixelWidth: 240, pixelHeight: 240)
        }
        return cute + food
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("COMPONENT PLAYGROUND")
                                .font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.tint)
                            Text("Sticker Keyboard")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            Text("A clean test host for the real reusable component. Tap emoji or stickers to see selection events.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            metric(title: "Selected", value: selectedStickerName, icon: "hand.tap")
                            metric(title: "Last search", value: lastSearch, icon: "magnifyingglass")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Message draft", systemImage: "text.bubble")
                                .font(.subheadline.weight(.semibold))
                            Text(draft.isEmpty ? "Your selected emoji and stickers appear here." : draft)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text("INTERACTION CHECKLIST").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
                            Label("Switch Emoji / Favorites / sticker packs", systemImage: "checkmark.circle")
                            Label("Select emoji and image sticker", systemImage: "checkmark.circle")
                            Label("Open search and submit a term", systemImage: "checkmark.circle")
                            Label("Verify category icons and sticker thumbnails load", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline)
                    }
                    .padding(20)
                }
                Divider()
                StickerKeyboard(
                    stickers: stickers,
                    packs: packs,
                    assets: assets,
                    userConfiguration: UserStickerConfiguration(selectedPackIDs: installedPackIDs, favoriteStickerIDs: ["cute-1", "cute-4"]),
                    defaultPackID: packID,
                    configuration: .init(height: 292, columns: 5, stickerSize: 54, categoryBarHeight: 48),
                    onSearch: { lastSearch = $0 },
                    onSearchRequested: { searchPresented = true },
                    onEmojiSelect: { emoji in
                        draft += emoji
                        selectedStickerName = "Emoji \(emoji)"
                    },
                    onSelect: { sticker in
                        draft += "[\(sticker.name ?? "Sticker")]"
                        selectedStickerName = sticker.name ?? sticker.id
                    }
                )
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("StickerKeyboardDemo")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                GeometryReader { proxy in
                    StickerSearchSheet(
                    isPresented: $searchPresented,
                    configuration: .init(sheet: .init(height: .fraction(0.90))),
                    packs: packs,
                    stickers: stickers,
                    assets: Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }),
                    installedPackIDs: Set(installedPackIDs),
                    installedPackVersions: installedPackVersions,
                    likedPackIDs: likedPackIDs,
                    onInstallPack: { pack in
                        if !installedPackIDs.contains(pack.id) { installedPackIDs.append(pack.id) }
                        installedPackVersions[pack.id] = pack.version
                    },
                    onDeletePack: { pack in
                        installedPackIDs.removeAll { $0 == pack.id }
                        installedPackVersions.removeValue(forKey: pack.id)
                    },
                    onLikePack: { pack, liked in
                        if liked { likedPackIDs.insert(pack.id) } else { likedPackIDs.remove(pack.id) }
                    },
                    onSearch: { lastSearch = $0 }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea(.container, edges: .all)
                .zIndex(2)
            }
        }
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

