import CrossProjectComponentsIOS
import SwiftUI

@main
struct ImgThumbnailDemoApp: App {
    var body: some Scene {
        WindowGroup { ImgThumbnailDemoView() }
    }
}

private struct ImgThumbnailDemoView: View {
    private let photoURLs: [URL] = [
        URL(string: "https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=800&auto=format&fit=crop&q=80")!,
        URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800&auto=format&fit=crop&q=80")!,
        URL(string: "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=800&auto=format&fit=crop&q=80")!,
        URL(string: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&auto=format&fit=crop&q=80")!
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cross-project component", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        Text("ImgThumbnail").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("One image API, four display shapes. Images fill the frame without stretching, using centered cropping.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    sectionTitle("SHAPES", subtitle: "Same source image, different clipping")
                    HStack(alignment: .top, spacing: 12) {
                        shapeSample("Rectangle", shape: .rectangle)
                        shapeSample("Smooth corners", shape: .roundedRectangle(cornerRadius: 18))
                        shapeSample("Square crop", shape: .square)
                        shapeSample("Circle", shape: .circle)
                    }
                    sectionTitle("LANDSCAPE THUMBNAILS", subtitle: "Different aspect ratios, same fill behavior")
                    VStack(spacing: 12) {
                        ImgThumbnail(url: photoURLs[0], size: CGSize(width: 320, height: 132), shape: .roundedRectangle(cornerRadius: 16))
                        HStack(spacing: 12) {
                            ImgThumbnail(url: photoURLs[1], size: CGSize(width: 150, height: 190), shape: .roundedRectangle(cornerRadius: 12))
                            ImgThumbnail(url: photoURLs[2], size: CGSize(width: 150, height: 190), shape: .roundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    sectionTitle("LOCAL IMAGES", subtitle: "No network request for local SwiftUI images")
                    HStack(spacing: 14) {
                        ImgThumbnail(image: Image(systemName: "photo.fill"), size: CGSize(width: 76, height: 76), shape: .roundedRectangle(cornerRadius: 12)).foregroundStyle(.blue)
                        ImgThumbnail(image: Image(systemName: "mountain.2.fill"), size: CGSize(width: 76, height: 76), shape: .circle).foregroundStyle(.green)
                        ImgThumbnail(image: Image(systemName: "person.crop.square.fill"), size: CGSize(width: 76, height: 76), shape: .square).foregroundStyle(.purple)
                    }
                    Text("Remote images are loaded through NukeUI. The component does not create a separate cache or downloader.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Thumbnail Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func shapeSample(_ title: String, shape: ImgThumbnail.ShapeStyle) -> some View {
        VStack(spacing: 8) {
            ImgThumbnail(url: photoURLs[0], size: CGSize(width: 74, height: 74), shape: shape)
            Text(title).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }.frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
            Text(subtitle).font(.subheadline.weight(.medium))
        }
    }
}
