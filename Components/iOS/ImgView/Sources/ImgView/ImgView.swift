import SwiftUI
import Nuke
import NukeUI

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
    @State private var retryToken = 0

    private static let imagePipeline = ImagePipeline { configuration in
        configuration.isProgressiveDecodingEnabled = true
    }

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
                Color.black.ignoresSafeArea()

                if images.indices.contains(selection) {
                    imageContent(images[selection], size: geometry.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .gesture(dragGesture)
                        .simultaneousGesture(magnificationGesture)
                        .onTapGesture(count: 2, perform: toggleZoom)
                        .accessibilityLabel("Image preview")
                } else {
                    ContentUnavailableView("No Image", systemImage: "photo")
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(spacing: 0) {
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("Close image viewer")

                        Spacer()

                        if images.indices.contains(selection) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showsInfo.toggle() }
                                if showsInfo, images.indices.contains(selection) { onInfoPanelPresented?(images[selection]) }
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .accessibilityLabel(showsInfo ? "Hide image information" : "Show image information")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer(minLength: 0)

                    if showsInfo {
                        infoPanel
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if images.count > 1 {
                        HStack(spacing: 18) {
                            Button { select(selection - 1) } label: { Image(systemName: "chevron.left") }
                                .disabled(selection == 0)
                            Text("\(selection + 1) / \(images.count)")
                                .monospacedDigit()
                                .font(.footnote.weight(.medium))
                            Button { select(selection + 1) } label: { Image(systemName: "chevron.right") }
                                .disabled(selection == images.count - 1)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .preferredColorScheme(.dark)
            .statusBarHidden()
            .onChange(of: isPresented) { _, presented in
                if !presented { showsInfo = false }
            }
        }
        .background(Color.black)
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
            .pipeline(Self.imagePipeline)
            .id(retryToken)
        }
        .scaleEffect(zoom)
        .offset(offset)
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in zoom = min(max(zoomAtGestureStart * value, 1), 5) }
            .onEnded { _ in
                zoomAtGestureStart = zoom
                if zoom <= 1 { withAnimation(.spring(response: 0.25)) { offset = .zero; offsetAtGestureStart = .zero } }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard zoom > 1 else { return }
                offset = CGSize(width: offsetAtGestureStart.width + value.translation.width,
                                height: offsetAtGestureStart.height + value.translation.height)
            }
            .onEnded { _ in offsetAtGestureStart = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            zoom = zoom > 1 ? 1 : 2
            zoomAtGestureStart = zoom
            if zoom == 1 { offset = .zero; offsetAtGestureStart = .zero }
        }
    }

    private func select(_ index: Int) {
        guard images.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            selection = index
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
