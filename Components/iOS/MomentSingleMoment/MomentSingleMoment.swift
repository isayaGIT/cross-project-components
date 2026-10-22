import SwiftUI
import NukeUI

/// A single WeChat-style Moments post. The host owns persistence and supplies the latest interaction state.
public struct MomentSingleMoment: View {
    /// A person displayed as the post author, a liker, or a commenter.
    public struct Person: Identifiable, Hashable, Sendable {
        public let id: String
        public var name: String
        public var avatarURL: URL?

        public init(
            id: String,
            name: String,
            avatarURL: URL? = nil
        ) {
            self.id = id
            self.name = name
            self.avatarURL = avatarURL
        }
    }

    /// A photo with an optional lower-resolution thumbnail URL.
    public struct Media: Identifiable, Hashable, Sendable {
        public let id: String
        public let url: URL
        public let previewURL: URL?
        public var accessibilityLabel: String?

        public init(
            id: String = UUID().uuidString,
            url: URL,
            previewURL: URL? = nil,
            accessibilityLabel: String? = nil
        ) {
            self.id = id
            self.url = url
            self.previewURL = previewURL
            self.accessibilityLabel = accessibilityLabel
        }

        var imgViewImage: ImgViewImage {
            ImgViewImage(id: id, url: url, previewURL: previewURL)
        }
    }

    /// A comment or reply shown in the interaction panel.
    public struct Comment: Identifiable, Hashable, Sendable {
        public let id: String
        public var author: Person
        public var text: String
        public var replyTo: Person?
        public var createdAt: Date?

        public init(
            id: String = UUID().uuidString,
            author: Person,
            text: String,
            replyTo: Person? = nil,
            createdAt: Date? = nil
        ) {
            self.id = id
            self.author = author
            self.text = text
            self.replyTo = replyTo
            self.createdAt = createdAt
        }
    }

    /// All display data and the latest interaction state for one post.
    public struct Model: Hashable, Sendable {
        public var author: Person
        public var text: String
        public var media: [Media]
        public var createdAt: Date
        public var location: String?
        public var mood: String?
        public var isLikedByCurrentUser: Bool
        public var likes: [Person]
        public var comments: [Comment]

        public init(
            author: Person,
            text: String,
            media: [Media] = [],
            createdAt: Date = .now,
            location: String? = nil,
            mood: String? = nil,
            isLikedByCurrentUser: Bool = false,
            likes: [Person] = [],
            comments: [Comment] = []
        ) {
            self.author = author
            self.text = text
            self.media = media
            self.createdAt = createdAt
            self.location = location
            self.mood = mood
            self.isLikedByCurrentUser = isLikedByCurrentUser
            self.likes = likes
            self.comments = comments
        }
    }

    private let model: Model
    private let onToggleLike: (Bool) -> Void
    private let onComment: (String) -> Void
    private let onAuthorTap: (() -> Void)?
    private let onMediaTap: ((Int) -> Void)?
    private let fontName: String?
    private let fontDesign: Font.Design
    private let authorNameFontSize: CGFloat
    private let contentFontSize: CGFloat
    private let metadataFontSize: CGFloat
    private let likesFontSize: CGFloat
    private let commentFontSize: CGFloat
    private let composerFontSize: CGFloat
    private let actionFontSize: CGFloat
    private let accentColor: Color
    private let textColor: Color
    private let secondaryTextColor: Color
    private let backgroundColor: Color
    private let interactionBackgroundColor: Color
    private let fieldBackgroundColor: Color
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let containerShape: AnyShape
    private let avatarShape: AnyShape
    private let interactionPanelShape: AnyShape
    private let composerShape: AnyShape
    private let mediaShape: ImgThumbnail.ShapeStyle
    private let palette = ComponentDesignPalette.warmEmber

    @State private var showsCommentComposer = false
    @State private var commentDraft = ""
    @State private var showsImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var imageInfoText = ""
    @State private var imageInfoURL = ""
    @State private var mediaPage = 0
    @State private var mediaDragOffset: CGFloat = 0

    /// Creates a post view. The host remains responsible for persistence and authoritative state.
    public init(
        model: Model,
        onToggleLike: @escaping (Bool) -> Void,
        onComment: @escaping (String) -> Void,
        onAuthorTap: (() -> Void)? = nil,
        onMediaTap: ((Int) -> Void)? = nil,
        fontName: String? = nil,
        fontDesign: Font.Design = .default,
        authorNameFontSize: CGFloat = 15,
        contentFontSize: CGFloat = 15,
        metadataFontSize: CGFloat = 11,
        likesFontSize: CGFloat = 12,
        commentFontSize: CGFloat = 13,
        composerFontSize: CGFloat = 14,
        actionFontSize: CGFloat = 14,
        accentColor: Color = ComponentDesignPalette.warmEmber.accent,
        textColor: Color = ComponentDesignPalette.warmEmber.textColor,
        secondaryTextColor: Color = ComponentDesignPalette.warmEmber.secondaryTextColor,
        backgroundColor: Color = ComponentDesignPalette.warmEmber.canvas,
        interactionBackgroundColor: Color = ComponentDesignPalette.warmEmber.fieldBackground.opacity(0.72),
        fieldBackgroundColor: Color = ComponentDesignPalette.warmEmber.fieldBackground,
        borderColor: Color = ComponentDesignPalette.warmEmber.borderColor,
        borderWidth: CGFloat = 0.5,
        containerShape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 0, style: .continuous)),
        avatarShape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 5, style: .continuous)),
        interactionPanelShape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous)),
        composerShape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 9, style: .continuous)),
        mediaShape: ImgThumbnail.ShapeStyle = .square
    ) {
        self.model = model
        self.onToggleLike = onToggleLike
        self.onComment = onComment
        self.onAuthorTap = onAuthorTap
        self.onMediaTap = onMediaTap
        self.fontName = fontName
        self.fontDesign = fontDesign
        self.authorNameFontSize = authorNameFontSize
        self.contentFontSize = contentFontSize
        self.metadataFontSize = metadataFontSize
        self.likesFontSize = likesFontSize
        self.commentFontSize = commentFontSize
        self.composerFontSize = composerFontSize
        self.actionFontSize = actionFontSize
        self.accentColor = accentColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.backgroundColor = backgroundColor
        self.interactionBackgroundColor = interactionBackgroundColor
        self.fieldBackgroundColor = fieldBackgroundColor
        self.borderColor = borderColor
        self.borderWidth = max(0, borderWidth)
        self.containerShape = containerShape
        self.avatarShape = avatarShape
        self.interactionPanelShape = interactionPanelShape
        self.composerShape = composerShape
        self.mediaShape = mediaShape
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
                            .font(componentFont(size: authorNameFontSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }

                if !model.text.isEmpty {
                    Text(model.text)
                        .font(componentFont(size: contentFontSize))
                        .foregroundStyle(textColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
                if !model.media.isEmpty {
                    mediaGrid
                        .padding(.top, 12)
                }

                HStack(alignment: .center, spacing: 8) {
                    if let mood = model.mood, !mood.isEmpty {
                        Text(mood).font(componentFont(size: metadataFontSize))
                    }
                    if let location = model.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    Text(Self.relativeDate(model.createdAt))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if !model.media.isEmpty {
                        let pageCount = max(1, Int(ceil(Double(model.media.count) / 9.0)))
                        if pageCount > 1 {
                            ScrollView(.horizontal) {
                                HStack(spacing: 1) {
                                    ForEach(0..<pageCount, id: \.self) { page in
                                        Button {
                                            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                                                mediaPage = page
                                            }
                                        } label: {
                                            Circle()
                                                .fill(page == min(mediaPage, pageCount - 1) ? accentColor : secondaryTextColor.opacity(0.35))
                                                .frame(width: page == min(mediaPage, pageCount - 1) ? 7 : 5, height: page == min(mediaPage, pageCount - 1) ? 7 : 5)
                                                .frame(width: 8, height: 20)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("第 \(page + 1) 页，共 \(pageCount) 页")
                                    }
                                }
                            }
                            .frame(width: min(CGFloat(pageCount) * 8, 64), height: 24)
                            .clipped()
                        }
                    }
                    Menu {
                        Button {
                            onToggleLike(!model.isLikedByCurrentUser)
                        } label: {
                            Label(
                model.isLikedByCurrentUser ? "取消赞" : "赞",
                systemImage: model.isLikedByCurrentUser ? "heart.slash" : "heart"
            )
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showsCommentComposer = true
                            }
                        } label: {
                            Label("评论", systemImage: "bubble.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 30, height: 24)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("动态操作")
                }
                .font(componentFont(size: metadataFontSize))
                .foregroundStyle(secondaryTextColor)
                .padding(.top, 9)

                if !model.likes.isEmpty || !model.comments.isEmpty {
                    interactionPanel
                        .padding(.top, 10)
                }

                if showsCommentComposer {
                    HStack(spacing: 8) {
                        TextField("评论…", text: $commentDraft, axis: .vertical)
                            .lineLimit(1...4)
                            .font(componentFont(size: composerFontSize))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(fieldBackgroundColor, in: composerShape)
                        Button("发送") {
                            let value = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else { return }
                            onComment(value)
                            commentDraft = ""
                            showsCommentComposer = false
                        }
                        .font(componentFont(size: actionFontSize, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 9)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: containerShape)
        .overlay { containerShape.stroke(borderColor, lineWidth: borderWidth) }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsImageViewer) {
            ImgView(
                isPresented: $showsImageViewer,
                images: model.media.map(\.imgViewImage),
                initialIndex: selectedImageIndex,
                onInfoPanelPresented: { image in
                    imageInfoText = model.media.first(where: { $0.id == image.id })?.accessibilityLabel
                        ?? image.url.lastPathComponent
                    imageInfoURL = image.url.absoluteString
                }
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("图片信息")
                        .font(.headline)
                    Text(imageInfoText.isEmpty ? "当前图片" : imageInfoText)
                        .font(.subheadline)
                    if !imageInfoURL.isEmpty {
                        Text(imageInfoURL)
                            .font(.caption)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
                .foregroundStyle(textColor)
            }
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
                let pageHeight = mediaGridHeight(width: pageWidth, itemCount: 9)
                HStack(spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        mediaPageGrid(page: page, allMedia: allMedia, width: pageWidth)
                            .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
                    }
                }
                .offset(x: -CGFloat(safePage) * pageWidth + mediaDragOffset)
                .frame(width: pageWidth, height: pageHeight, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
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
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .onChange(of: model.media.count) { newCount in
            mediaPage = min(mediaPage, max(0, (newCount - 1) / 9))
        }
    }

    private func mediaGridHeight(width: CGFloat, itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        if itemCount == 1 { return 220 }
        let columns = itemCount == 2 || itemCount == 4 ? 2 : 3
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        let tile = (width - CGFloat(columns - 1) * 4) / CGFloat(columns)
        return CGFloat(rows) * tile + CGFloat(max(0, rows - 1)) * 4
    }

    private func mediaPageGrid(page: Int, allMedia: [Media], width: CGFloat) -> some View {
        let pageStart = page * 9
        let pageItems = Array(allMedia.dropFirst(pageStart).prefix(9))
        let count = pageItems.count
        let columns = count == 1 ? 1 : (count == 2 || count == 4 ? 2 : 3)
        let gridColumns = Array(repeating: GridItem(.fixed((width - CGFloat(columns - 1) * 4) / CGFloat(columns)), spacing: 4), count: columns)
        let tileSize = (width - CGFloat(columns - 1) * 4) / CGFloat(columns)

        return LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 4) {
            ForEach(Array(pageItems.enumerated()), id: \.element.id) { pageIndex, item in
                let index = pageStart + pageIndex
                Button {
                    selectedImageIndex = index
                    if onMediaTap != nil { onMediaTap?(index) }
                    else { showsImageViewer = true }
                } label: {
                    ImgThumbnail(
                        url: item.previewURL ?? item.url,
                        size: CGSize(width: tileSize, height: count == 1 ? min(220, tileSize) : tileSize),
                        shape: mediaShape,
                        placeholder: Image(systemName: "photo"),
                        showsLoadingIndicator: true
                    )
                    .frame(width: tileSize, height: count == 1 ? min(220, tileSize) : tileSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel ?? "Photo \(index + 1) of \(allMedia.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interactionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.likes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(componentFont(size: likesFontSize, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.top, 3)
                    Text(model.likes.map(\.name).joined(separator: ", "))
                        .font(componentFont(size: likesFontSize, weight: .medium))
                        .foregroundStyle(accentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }

            if !model.likes.isEmpty && !model.comments.isEmpty {
                Rectangle().fill(borderColor.opacity(0.7)).frame(height: borderWidth)
            }

            if !model.comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.comments) { comment in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(comment.author.name)
                                    .foregroundStyle(accentColor)
                                    .fontWeight(.semibold)
                                if let target = comment.replyTo {
                                    Text("replied to").foregroundStyle(secondaryTextColor)
                                    Text(target.name).foregroundStyle(accentColor).fontWeight(.semibold)
                                }
                                Text(":").foregroundStyle(textColor)
                                Text(comment.text).foregroundStyle(textColor)
                            }
                            .font(componentFont(size: commentFontSize))
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(interactionBackgroundColor, in: interactionPanelShape)
        .overlay { interactionPanelShape.stroke(borderColor.opacity(0.7), lineWidth: borderWidth) }
    }

    @ViewBuilder
    private func avatar(_ person: Person, size: CGFloat) -> some View {
        Group {
            if let url = person.avatarURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .clipShape(avatarShape)
        .accessibilityHidden(true)
    }

    private func componentFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName, !fontName.isEmpty {
            return .custom(fontName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }

    private static func relativeDate(_ date: Date) -> String {// todo 删掉 不需要这个逻辑
        let seconds = max(0, Int(Date.now.timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)分钟前" }
        if seconds < 86_400 { return "\(seconds / 3600)小时前" }
        if seconds < 604_800 { return "\(seconds / 86_400)天前" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
