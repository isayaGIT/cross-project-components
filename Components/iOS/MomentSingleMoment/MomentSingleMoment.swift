import SwiftUI
import NukeUI

/// A single WeChat-style Moments post. The host owns persistence and supplies the latest interaction state.
public struct MomentSingleMoment: View {
    public struct Person: Identifiable, Hashable, Sendable {
        public let id: String
        public var name: String
        public var avatarURL: URL?
        public var fallbackSymbol: String

        public init(id: String, name: String, avatarURL: URL? = nil, fallbackSymbol: String = "person.crop.circle.fill") {
            self.id = id
            self.name = name
            self.avatarURL = avatarURL
            self.fallbackSymbol = fallbackSymbol
        }
    }

    public struct Media: Identifiable, Hashable, Sendable {
        public let id: String
        public let url: URL
        public let previewURL: URL?
        public var accessibilityLabel: String?

        public init(id: String = UUID().uuidString, url: URL, previewURL: URL? = nil, accessibilityLabel: String? = nil) {
            self.id = id
            self.url = url
            self.previewURL = previewURL
            self.accessibilityLabel = accessibilityLabel
        }

        var imgViewImage: ImgViewImage { ImgViewImage(id: id, url: url, previewURL: previewURL) }
    }

    public struct Comment: Identifiable, Hashable, Sendable {
        public let id: String
        public var author: Person
        public var text: String
        public var replyTo: Person?
        public var createdAt: Date?

        public init(id: String = UUID().uuidString, author: Person, text: String, replyTo: Person? = nil, createdAt: Date? = nil) {
            self.id = id
            self.author = author
            self.text = text
            self.replyTo = replyTo
            self.createdAt = createdAt
        }
    }

    public struct Model: Hashable, Sendable {
        public var author: Person
        public var text: String
        public var media: [Media]
        public var createdAt: Date
        public var location: String?
        public var mood: String?
        public var isLikedByCurrentUser: Bool
        public var hasCommentedByCurrentUser: Bool
        public var likes: [Person]
        public var comments: [Comment]

        public init(author: Person, text: String, media: [Media] = [], createdAt: Date = .now, location: String? = nil, mood: String? = nil, isLikedByCurrentUser: Bool = false, hasCommentedByCurrentUser: Bool = false, likes: [Person] = [], comments: [Comment] = []) {
            self.author = author
            self.text = text
            self.media = Array(media.prefix(9))
            self.createdAt = createdAt
            self.location = location
            self.mood = mood
            self.isLikedByCurrentUser = isLikedByCurrentUser
            self.hasCommentedByCurrentUser = hasCommentedByCurrentUser
            self.likes = likes
            self.comments = comments
        }
    }

    private let model: Model
    private let onToggleLike: (Bool) -> Void
    private let onComment: (String) -> Void
    private let onAuthorTap: (() -> Void)?
    private let onMediaTap: ((Int) -> Void)?
    private let palette: ComponentDesignPalette
    private let likeIcon: Image?
    private let likedIcon: Image?
    private let commentIcon: Image?
    private let commentedIcon: Image?
    private let actionIconTint: Color?

    @State private var showsCommentComposer = false
    @State private var commentDraft = ""
    @State private var showsImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var mediaPage = 0
    @State private var mediaDragOffset: CGFloat = 0

    public init(
        model: Model,
        palette: ComponentDesignPalette = .warmEmber,
        onToggleLike: @escaping (Bool) -> Void,
        onComment: @escaping (String) -> Void,
        onAuthorTap: (() -> Void)? = nil,
        onMediaTap: ((Int) -> Void)? = nil,
        likeIcon: Image? = nil,
        likedIcon: Image? = nil,
        commentIcon: Image? = nil,
        commentedIcon: Image? = nil,
        actionIconTint: Color? = nil
    ) {
        self.model = model
        self.palette = palette
        self.onToggleLike = onToggleLike
        self.onComment = onComment
        self.onAuthorTap = onAuthorTap
        self.onMediaTap = onMediaTap
        self.likeIcon = likeIcon
        self.likedIcon = likedIcon
        self.commentIcon = commentIcon
        self.commentedIcon = commentedIcon
        self.actionIconTint = actionIconTint
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Button { onAuthorTap?() } label: {
                avatar(model.author, size: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(model.author.name)'s profile")

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Button { onAuthorTap?() } label: {
                        Text(model.author.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }

                if !model.text.isEmpty {
                    Text(model.text)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }

                if !model.media.isEmpty {
                    mediaGrid
                        .padding(.top, 9)
                }

                HStack(spacing: 8) {
                    if let mood = model.mood, !mood.isEmpty {
                        Text(mood).font(.system(size: 12))
                    }
                    if let location = model.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    Text(Self.relativeDate(model.createdAt))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    HStack(spacing: 13) {
                        Button { onToggleLike(!model.isLikedByCurrentUser) } label: {
                            actionGlyph(
                                custom: model.isLikedByCurrentUser ? (likedIcon ?? likeIcon) : likeIcon,
                                fallback: model.isLikedByCurrentUser ? "heart.fill" : "heart",
                                isActive: model.isLikedByCurrentUser
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.isLikedByCurrentUser ? "取消赞" : "赞")

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { showsCommentComposer.toggle() }
                        } label: {
                            actionGlyph(
                                custom: model.hasCommentedByCurrentUser ? (commentedIcon ?? commentIcon) : commentIcon,
                                fallback: model.hasCommentedByCurrentUser ? "bubble.right.fill" : "bubble.right",
                                isActive: model.hasCommentedByCurrentUser
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.hasCommentedByCurrentUser ? "继续评论" : "评论")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(palette.secondaryTextColor)
                .padding(.top, 9)

                if !model.likes.isEmpty || !model.comments.isEmpty {
                    interactionPanel
                        .padding(.top, 10)
                }

                if showsCommentComposer {
                    HStack(spacing: 8) {
                        TextField("评论…", text: $commentDraft, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 14))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(palette.fieldBackground, in: RoundedRectangle(cornerRadius: 9))
                        Button("发送") {
                            let value = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else { return }
                            onComment(value)
                            commentDraft = ""
                            showsCommentComposer = false
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 9)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.canvas)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.borderColor.opacity(0.7)).frame(height: 0.5) }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsImageViewer) {
            ImgView(isPresented: $showsImageViewer, images: model.media.map(\.imgViewImage), initialIndex: selectedImageIndex)
        }
        #endif
    }

    private var mediaGrid: some View {
        let allMedia = model.media
        let pageCount = max(1, Int(ceil(Double(allMedia.count) / 9.0)))
        let safePage = min(mediaPage, pageCount - 1)

        return VStack(alignment: .trailing, spacing: 7) {
            GeometryReader { geometry in
                // Match the interaction panel's full width, including the pagination viewport.
                let pageWidth = geometry.size.width
                let pageHeight = mediaGridHeight(width: pageWidth, itemCount: min(9, allMedia.count))
                HStack(spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        mediaPageGrid(page: page, allMedia: allMedia)
                            .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
                    }
                }
                .offset(x: -CGFloat(safePage) * pageWidth + mediaDragOffset)
                .frame(width: pageWidth, height: pageHeight, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .local)
                        .onChanged { value in
                            guard pageCount > 1, abs(value.translation.width) > abs(value.translation.height) else { return }
                            let proposed = -CGFloat(safePage) * pageWidth + value.translation.width
                            let minOffset = -CGFloat(pageCount - 1) * pageWidth
                            let maxOffset: CGFloat = 0
                            if proposed < minOffset {
                                mediaDragOffset = minOffset + (proposed - minOffset) * 0.22 + CGFloat(safePage) * pageWidth
                            } else if proposed > maxOffset {
                                mediaDragOffset = maxOffset + (proposed - maxOffset) * 0.22 + CGFloat(safePage) * pageWidth
                            } else {
                                mediaDragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            guard pageCount > 1, abs(value.translation.width) > abs(value.translation.height) else {
                                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) { mediaDragOffset = 0 }
                                return
                            }
                            let predicted = value.predictedEndTranslation.width
                            let travel = abs(predicted) > abs(value.translation.width) * 1.15 ? predicted : value.translation.width
                            let threshold = max(36, pageWidth * 0.18)
                            var nextPage = safePage
                            if travel < -threshold { nextPage += max(1, Int((abs(travel) / pageWidth).rounded(.down))) }
                            else if travel > threshold { nextPage -= max(1, Int((abs(travel) / pageWidth).rounded(.down))) }
                            nextPage = min(pageCount - 1, max(0, nextPage))
                            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.12)) {
                                mediaPage = nextPage
                                mediaDragOffset = 0
                            }
                        }
                )
            }
            .aspectRatio(mediaGridAspectRatio(itemCount: min(9, allMedia.count)), contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .leading)

            if pageCount > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Button {
                            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) { mediaPage = page }
                        } label: {
                            Circle()
                                .fill(page == safePage ? palette.accent : palette.secondaryTextColor.opacity(0.35))
                                .frame(width: page == safePage ? 7 : 5, height: page == safePage ? 7 : 5)
                                .frame(width: 12, height: 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(page + 1) 页，共 \(pageCount) 页")
                    }
                }
                .padding(.trailing, 2)
            }
        }
        .onChange(of: model.media.count) { newCount in
            mediaPage = min(mediaPage, max(0, (newCount - 1) / 9))
        }
    }

    private func mediaGridAspectRatio(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 1 }
        if itemCount == 1 { return 1.0 } // The single-photo presentation is height-capped below.
        let columns = itemCount == 2 || itemCount == 4 ? 2 : 3
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        return CGFloat(columns) / CGFloat(rows)
    }

    private func mediaGridHeight(width: CGFloat, itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        if itemCount == 1 { return 220 }
        let columns = itemCount == 2 || itemCount == 4 ? 2 : 3
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        let tile = (width - CGFloat(columns - 1) * 4) / CGFloat(columns)
        return CGFloat(rows) * tile + CGFloat(max(0, rows - 1)) * 4
    }

    private func mediaPageGrid(page: Int, allMedia: [Media]) -> some View {
        let pageStart = page * 9
        let pageItems = Array(allMedia.dropFirst(pageStart).prefix(9))
        let count = pageItems.count
        let columns = count == 1 ? 1 : (count == 2 || count == 4 ? 2 : 3)
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)

        return LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 4) {
            ForEach(Array(pageItems.enumerated()), id: \.element.id) { pageIndex, item in
                let index = pageStart + pageIndex
                Button {
                    selectedImageIndex = index
                    if onMediaTap != nil { onMediaTap?(index) }
                    else { showsImageViewer = true }
                } label: {
                    ZStack {
                        Rectangle().fill(palette.fieldBackground)
                        // Temporary renderer: replace with the shared ImageThumbnail component when its API is ready.
                        LazyImage(url: item.previewURL ?? item.url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if state.error != nil {
                                Image(systemName: "photo")
                                    .font(.system(size: 22))
                                    .foregroundStyle(palette.secondaryTextColor)
                            } else {
                                ProgressView().tint(palette.secondaryTextColor)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: count == 1 ? 220 : nil)
                    .aspectRatio(count == 1 ? nil : 1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "Photo \(index + 1) of \(allMedia.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionGlyph(custom: Image?, fallback: String, isActive: Bool) -> some View {
        Group {
            if let custom {
                custom
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: fallback)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
        }
        .foregroundStyle(actionIconTint ?? (isActive ? palette.accent : palette.secondaryTextColor))
        .frame(width: 18, height: 18)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }

    private var interactionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.likes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .padding(.top, 3)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), alignment: .leading)], alignment: .leading, spacing: 7) {
                        ForEach(model.likes) { person in
                            HStack(spacing: 4) {
                                avatar(person, size: 20)
                                Text(person.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }

            if !model.likes.isEmpty && !model.comments.isEmpty {
                Rectangle().fill(palette.borderColor.opacity(0.7)).frame(height: 0.5)
            }

            if !model.comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.comments) { comment in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(comment.author.name)
                                    .foregroundStyle(palette.accent)
                                    .fontWeight(.semibold)
                                if let target = comment.replyTo {
                                    Text("replied to").foregroundStyle(palette.secondaryTextColor)
                                    Text(target.name).foregroundStyle(palette.accent).fontWeight(.semibold)
                                }
                                Text(":").foregroundStyle(palette.textColor)
                                Text(comment.text).foregroundStyle(palette.textColor)
                            }
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                            if let date = comment.createdAt {
                                Text(Self.relativeDate(date))
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.secondaryTextColor)
                            }
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.fieldBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func avatar(_ person: Person, size: CGFloat) -> some View {
        Group {
            if let url = person.avatarURL {
                LazyImage(url: url) { state in
                    if let image = state.image { image.resizable().aspectRatio(contentMode: .fill) }
                    else { fallbackAvatar(person) }
                }
            } else {
                fallbackAvatar(person)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size < 24 ? 3 : 5, style: .continuous))
        .accessibilityHidden(true)
    }

    private func fallbackAvatar(_ person: Person) -> some View {
        ZStack {
            palette.previewAccentSurface
            Image(systemName: person.fallbackSymbol)
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(palette.accent)
        }
    }

    private static func relativeDate(_ date: Date) -> String {
        let seconds = max(0, Int(Date.now.timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)分钟前" }
        if seconds < 86_400 { return "\(seconds / 3600)小时前" }
        if seconds < 604_800 { return "\(seconds / 86_400)天前" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
