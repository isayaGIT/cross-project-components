import SwiftUI
import Photos
import Nuke
import NukeUI

private enum ImgViewPipeline {
    static let shared = ImagePipeline { configuration in
        configuration.isProgressiveDecodingEnabled = true
    }
}

/// A reusable, full-screen image viewer with optional low-resolution previews and an injectable info panel.
public struct ImgView<InfoPanel: View>: View {
    @Binding private var isPresented: Bool
    private let images: [ImgViewImage]
    private let infoPanel: InfoPanel
    private let onInfoPanelPresented: ((ImgViewImage) -> Void)?

    @State private var selection: Int
    @State private var showsInfo = false
    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var offsetAtGestureStart: CGSize = .zero
    @State private var horizontalPageDrag: CGFloat = 0
    @State private var retryToken = 0
    @State private var viewerDismissOffset: CGFloat = 0
    @State private var blurEntranceProgress: CGFloat = 1
    @State private var interactionGeneration = 0
    @State private var tapDismissTask: Task<Void, Never>?
    @State private var highResolutionLoaded = false
    @State private var isSavingToPhotos = false
    @State private var showsPhotoAlert = false
    @State private var photoAlertTitle = ""
    @State private var photoAlertMessage = ""

    public init(
        isPresented: Binding<Bool>,
        images: [ImgViewImage],
        initialIndex: Int = 0,
        onInfoPanelPresented: ((ImgViewImage) -> Void)? = nil,
        @ViewBuilder infoPanel: () -> InfoPanel
    ) {
        self._isPresented = isPresented
        self.images = images
        self.onInfoPanelPresented = onInfoPanelPresented
        self.infoPanel = infoPanel()
        self._selection = State(initialValue: max(0, min(initialIndex, max(0, images.count - 1))))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ImageViewerBlur(
                    style: .systemUltraThinMaterialDark,
                    // The backdrop is revealed during drag, and starts blurred on presentation.
                    // max() lets entrance and interactive drag share one stable effect view.
                    revealProgress: max(blurEntranceProgress, min(max(viewerDismissOffset / 180, 0), 1))
                )
                .ignoresSafeArea()

                ZStack {
                if images.indices.contains(selection) {
                    ZStack {
                        // Keep adjacent pages mounted while dragging so the incoming
                        // image follows the finger instead of appearing after release.
                        if zoom <= 1.01 {
                            if selection > 0 {
                                imageContent(images[selection - 1], size: geometry.size)
                                    .offset(x: -geometry.size.width + horizontalPageDrag)
                            }
                            if selection + 1 < images.count {
                                imageContent(images[selection + 1], size: geometry.size)
                                    .offset(x: geometry.size.width + horizontalPageDrag)
                            }
                        }

                        imageContent(images[selection], size: geometry.size)
                            .offset(x: horizontalPageDrag)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .offset(y: viewerDismissOffset)
                    .opacity(1 - min(max(viewerDismissOffset / max(geometry.size.height, 1), 0), 0.35))
                    .contentShape(Rectangle())
                        .gesture(dragGesture(size: geometry.size))
                        .simultaneousGesture(magnificationGesture)
                        .simultaneousGesture(imageTapGesture)
                        .accessibilityLabel("Image preview")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                        Text("No Image")
                            .font(.headline)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }

                VStack(spacing: 0) {
                    HStack {
                        Button(action: closeViewer) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.black.opacity(0.32)))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close image viewer")

                        Spacer()

                        if images.indices.contains(selection) {
                            Button(action: toggleInfo) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(showsInfo ? Color.black : Color.white)
                                    .frame(width: 40, height: 40)
                                    .background {
                                        Circle().fill(showsInfo ? Color.white : Color.black.opacity(0.32))
                                    }
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showsInfo ? "Hide image information" : "Show image information")

                            Menu {
                                Button {
                                    Task { await saveOriginalToPhotos(images[selection]) }
                                } label: {
                                    if isSavingToPhotos {
                                        Label("正在保存…", systemImage: "arrow.down.circle")
                                    } else {
                                        Label("保存到相册", systemImage: "square.and.arrow.down")
                                    }
                                }
                                .disabled(isSavingToPhotos)
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.black.opacity(0.32)))
                                    .contentShape(Circle())
                            }
                            .menuStyle(.borderlessButton)
                            .accessibilityLabel("More image actions")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer(minLength: 0)

                    if showsInfo {
                        ImgViewInfoPanel(onDismiss: dismissInfo) {
                            infoPanel
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .preferredColorScheme(.dark)
            #if os(iOS)
            .statusBarHidden()
            #endif
            .onAppear {
                blurEntranceProgress = 1
                withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                    blurEntranceProgress = 0
                }
            }
            .onChange(of: isPresented) { _, presented in
                if presented {
                    blurEntranceProgress = 1
                    withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                        blurEntranceProgress = 0
                    }
                } else {
                    tapDismissTask?.cancel()
                    tapDismissTask = nil
                    showsInfo = false
                }
            }
            .alert(photoAlertTitle, isPresented: $showsPhotoAlert) {
                Button("好", role: .cancel) { }
            } message: {
                Text(photoAlertMessage)
            }
        }
        .background(Color.clear)
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private func imageContent(_ image: ImgViewImage, size: CGSize) -> some View {
        ZStack {
            if let previewURL = image.previewURL {
                LazyImage(url: previewURL) { state in
                    if let preview = state.image {
                        preview.resizable().aspectRatio(contentMode: .fit)
                    }
                }
                .priority(.high)
            }

            // Keep a screen-sized rendition visible at all times. A second, un-downsampled
            // request is layered above it only after zoom begins, so resolution upgrades
            // never replace the view or reset the user's live pinch transform.
            LazyImage(url: image.url) { state in
                if let loaded = state.image {
                    loaded.resizable().aspectRatio(contentMode: .fit)
                        .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                } else if state.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                        Text("Image couldn't be loaded")
                        Button("Retry") { retryToken += 1 }
                            .buttonStyle(.bordered)
                    }
                    .padding(20)
                    .foregroundStyle(.white.opacity(0.9))
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                } else if image.previewURL == nil {
                    ProgressView().tint(.white)
                }
            }
            .processors([.resize(size: CGSize(width: size.width * 2, height: size.height * 2))])
            .priority(.high)
            .pipeline(ImgViewPipeline.shared)
            .id(retryToken)

            if zoom > 1.12 {
                LazyImage(url: image.url) { state in
                    if let original = state.image {
                        original.resizable().aspectRatio(contentMode: .fit)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    highResolutionLoaded = true
                                }
                            }
                    }
                }
                .priority(.veryHigh)
                .pipeline(ImgViewPipeline.shared)
                .opacity(highResolutionLoaded ? 1 : 0)
            }
        }
        .scaleEffect(zoom)
        .offset(offset)
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                dismissInfoForImageInteraction()
                zoom = min(max(zoomAtGestureStart * value, 1), 5)
                if zoom <= 1.12 { highResolutionLoaded = false }
            }
            .onEnded { _ in
                zoomAtGestureStart = zoom
                if zoom <= 1 { withAnimation(.spring(response: 0.25)) { offset = .zero; offsetAtGestureStart = .zero } }
            }
    }

    /// One drag recognizer arbitrates between panning a zoomed image and dismissing
    /// the viewer. Two simultaneous DragGestures caused competing state updates.
    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                interactionGeneration &+= 1
                tapDismissTask?.cancel()
                tapDismissTask = nil
                if viewerDismissOffset != 0 {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewerDismissOffset = 0
                    }
                }
                dismissInfoForImageInteraction()

                if zoom > 1.01 {
                    offset = CGSize(
                        width: offsetAtGestureStart.width + value.translation.width,
                        height: offsetAtGestureStart.height + value.translation.height
                    )
                    return
                }

                // Track horizontal page movement continuously, with no animation lag.
                if abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                    let proposed = value.translation.width
                    let atFirstPage = selection == 0 && proposed > 0
                    let atLastPage = selection == images.count - 1 && proposed < 0
                    let tracked = (atFirstPage || atLastPage) ? proposed * 0.22 : proposed
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        horizontalPageDrag = tracked
                    }
                    return
                }

                // Only dominant downward drags dismiss the viewer.
                guard abs(value.translation.width) <= abs(value.translation.height) * 1.2 else {
                    guard value.translation.height > 0,
                          value.translation.height > abs(value.translation.width) * 1.2 else { return }
                    // No implicit animation during tracking: render at the finger's current position.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewerDismissOffset = value.translation.height
                    }
                    return
                }

            }
            .onEnded { value in
                if zoom > 1.01 {
                    offsetAtGestureStart = offset
                    return
                }

                let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                if isHorizontal {
                    let travel = abs(value.predictedEndTranslation.width) > abs(value.translation.width) * 1.15
                        ? value.predictedEndTranslation.width
                        : value.translation.width
                    let target = selection + (travel < 0 ? 1 : -1)
                    let canChangePage = images.indices.contains(target)
                    let shouldTurnPage = canChangePage &&
                        (abs(value.translation.width) >= size.width * 0.20 || abs(travel) >= size.width * 0.32)

                    if shouldTurnPage {
                        let finalDrag = travel < 0 ? -size.width : size.width
                        let generation = interactionGeneration
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88)) {
                            horizontalPageDrag = finalDrag
                        } completion: {
                            guard interactionGeneration == generation else { return }
                            // Swap only after the page animation finishes. A newer gesture
                            // invalidates this completion instead of letting stale work win.
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                selection = target
                                horizontalPageDrag = 0
                                highResolutionLoaded = false
                                zoom = 1
                                zoomAtGestureStart = 1
                                offset = .zero
                                offsetAtGestureStart = .zero
                                showsInfo = false
                            }
                        }
                    } else {
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88)) {
                            horizontalPageDrag = 0
                        }
                    }
                    return
                }

                let isDownward = value.translation.height > 0 &&
                    value.translation.height > abs(value.translation.width) * 1.2
                let passedDistance = value.translation.height >= 140
                let passedVelocity = value.predictedEndTranslation.height >= 260

                guard isDownward, passedDistance || passedVelocity else {
                    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88)) {
                        viewerDismissOffset = 0
                        horizontalPageDrag = 0
                    }
                    return
                }

                // Finish only if no newer interaction has interrupted this dismissal.
                let generation = interactionGeneration
                withAnimation(.easeOut(duration: 0.16), completionCriteria: .logicallyComplete) {
                    viewerDismissOffset = max(value.translation.height, 0) + 120
                    showsInfo = false
                } completion: {
                    guard interactionGeneration == generation else { return }
                    isPresented = false
                }
            }
    }

    /// A first tap begins dismissing immediately. If a second tap arrives, cancel that
    /// dismissal and zoom instead, rather than waiting for ExclusiveGesture to resolve.
    private var imageTapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded { beginTapDismiss() }
            .simultaneously(with: TapGesture(count: 2).onEnded { cancelTapDismissAndZoom() })
    }

    private func beginTapDismiss() {
        guard tapDismissTask == nil else { return }
        interactionGeneration &+= 1
        let generation = interactionGeneration
        withAnimation(.easeOut(duration: 0.22)) {
            viewerDismissOffset = 120
            showsInfo = false
        }
        tapDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(320))
            } catch {
                return
            }
            guard interactionGeneration == generation else { return }
            tapDismissTask = nil
            isPresented = false
        }
    }

    private func cancelTapDismissAndZoom() {
        tapDismissTask?.cancel()
        tapDismissTask = nil
        interactionGeneration &+= 1
        withAnimation(.easeOut(duration: 0.12)) {
            viewerDismissOffset = 0
        }
        toggleZoom()
    }

    private func closeViewer() {
        tapDismissTask?.cancel()
        tapDismissTask = nil
        interactionGeneration &+= 1
        showsInfo = false
        isPresented = false
    }

    private func toggleZoom() {
        dismissInfoForImageInteraction()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            zoom = zoom > 1 ? 1 : 2
            zoomAtGestureStart = zoom
            if zoom == 1 {
                highResolutionLoaded = false
                offset = .zero
                offsetAtGestureStart = .zero
            }
        }
    }

    private func toggleInfo() {
        let shouldShow = !showsInfo
        withAnimation(.easeInOut(duration: 0.2)) {
            showsInfo = shouldShow
        }
        if shouldShow, images.indices.contains(selection) {
            onInfoPanelPresented?(images[selection])
        }
    }

    private func dismissInfo() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            showsInfo = false
        }
    }

    /// Any direct interaction with the image dismisses the info surface using its bottom-edge transition.
    private func dismissInfoForImageInteraction() {
        guard showsInfo else { return }
        dismissInfo()
    }

    @MainActor
    private func saveOriginalToPhotos(_ image: ImgViewImage) async {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        let authorization = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
        guard authorization == .authorized || authorization == .limited else {
            presentPhotoAlert(title: "无法保存", message: "请在系统设置中允许此 App 添加照片到相册。")
            return
        }

        var temporaryFile: URL?
        do {
            let sourceURL: URL
            if image.url.isFileURL {
                sourceURL = image.url
            } else {
                let (downloadedURL, response) = try await URLSession.shared.download(from: image.url)
                if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                    throw URLError(.badServerResponse)
                }
                let fileExtension = image.url.pathExtension.isEmpty ? "jpg" : image.url.pathExtension
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)
                try FileManager.default.moveItem(at: downloadedURL, to: destination)
                temporaryFile = destination
                sourceURL = destination
            }
            defer {
                if let temporaryFile { try? FileManager.default.removeItem(at: temporaryFile) }
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, fileURL: sourceURL, options: nil)
                } completionHandler: { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: URLError(.cannotWriteToFile))
                    }
                }
            }
            presentPhotoAlert(title: "已保存", message: "原图已保存到相册。")
        } catch {
            presentPhotoAlert(title: "保存失败", message: "无法保存这张原图，请检查网络或相册权限后重试。")
        }
    }

    private func presentPhotoAlert(title: String, message: String) {
        photoAlertTitle = title
        photoAlertMessage = message
        showsPhotoAlert = true
    }

    private func select(_ index: Int) {
        guard images.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            selection = index
            highResolutionLoaded = false
            zoom = 1
            zoomAtGestureStart = 1
            offset = .zero
            offsetAtGestureStart = .zero
            showsInfo = false
        }
    }
}

public extension ImgView where InfoPanel == EmptyView {
    init(isPresented: Binding<Bool>, images: [ImgViewImage], initialIndex: Int = 0) {
        self.init(isPresented: isPresented, images: images, initialIndex: initialIndex, onInfoPanelPresented: nil) { EmptyView() }
    }
}

/// Image source metadata. `previewURL` should point to a genuinely smaller image when available.
public struct ImgViewImage: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let previewURL: URL?

    public init(id: String = UUID().uuidString, url: URL, previewURL: URL? = nil) {
        self.id = id
        self.url = url
        self.previewURL = previewURL
    }
}
