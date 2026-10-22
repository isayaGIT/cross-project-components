import SwiftUI
import ImgView

@main
struct ImgViewShowcaseApp: App {
    var body: some Scene {
        WindowGroup { ImgViewShowcase() }
    }
}

private struct ImgViewShowcase: View {
    @State private var showViewer = false
    @State private var showInfo = false
    @State private var aiState = "尚未请求识图"

    private let image = ImgViewImage(
        id: "large-landscape",
        url: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?fm=jpg&fit=max&w=6000&q=90")!,
        previewURL: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=max&w=480&q=35")!
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ImgView")
                        .font(.largeTitle.bold())
                    Text("Large-image loading, zoom gestures, preview fallback and an injectable AI information panel.")
                        .foregroundStyle(.secondary)
                    AsyncImage(url: image.previewURL) { phase in
                        if let preview = phase.image {
                            preview.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle().fill(.quaternary).overlay(ProgressView())
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    Button("Open full-screen image") { showViewer = true }
                        .buttonStyle(.borderedProminent)
                    GroupBox("Test checklist") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Preview appears before the large image", systemImage: "photo")
                            Label("Pinch to zoom and double-tap to zoom", systemImage: "hand.draw")
                            Label("Tap the info icon to open the AI panel", systemImage: "info.circle")
                            Label("Turn on Airplane Mode after first load to inspect cached behavior", systemImage: "airplane")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showViewer) {
                ImgView(isPresented: $showViewer, images: [image], onInfoPanelPresented: { _ in
                    aiState = "已触发识图回调：由宿主应用连接真实 AI 服务。"
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI 图片理解").font(.headline)
                        Text(aiState).font(.subheadline)
                        Button("生成识图结果") { aiState = "识图处理中（演示状态，不会调用真实 AI 服务）" }
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}
