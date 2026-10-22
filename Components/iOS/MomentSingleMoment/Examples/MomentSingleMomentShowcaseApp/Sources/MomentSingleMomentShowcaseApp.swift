import SwiftUI
import CrossProjectComponentsIOS

@main
struct MomentSingleMomentShowcaseApp: App {
    var body: some Scene {
        WindowGroup { MomentSingleMomentShowcase() }
    }
}

private struct MomentSingleMomentShowcase: View {
    private let author = MomentSingleMoment.Person(
        id: "author", name: "林间晚风",
        avatarURL: URL(string: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=160&q=80")
    )
    private let secondPerson = MomentSingleMoment.Person(
        id: "friend", name: "周周",
        avatarURL: URL(string: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80")
    )
    @State private var liked = false
    @State private var likes: [MomentSingleMoment.Person] = [
        .init(id: "friend", name: "周周", avatarURL: URL(string: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80")),
        .init(id: "momo", name: "沫沫")
    ]
    @State private var comments: [MomentSingleMoment.Comment] = [
        .init(id: "c1", author: .init(id: "friend", name: "周周"), text: "这光影也太好看了吧！"),
        .init(id: "c2", author: .init(id: "momo", name: "沫沫"), text: "下次一起去～", replyTo: .init(id: "friend", name: "周周"))
    ]
    private let photos: [MomentSingleMoment.Media] = [
        ("p1", "photo-1470770841072-f978cf4d019e"),
        ("p2", "photo-1441974231531-c6227db76b6e"),
        ("p3", "photo-1500530855697-b586d89ba3ee"),
        ("p4", "photo-1501785888041-af3ef285b470"),
        ("p5", "photo-1472396961693-142e6e269027"),
        ("p6", "photo-1470252649378-9c29740c9fa8"),
        ("p7", "photo-1464822759023-fed622ff2c3b"),
        ("p8", "photo-1500534623283-312aade485b7"),
        ("p9", "photo-1511497584788-876760111969"),
        ("p10", "photo-1506744038136-46273834b3fb"),
        ("p11", "photo-1518837695005-2083093ee35b"),
        ("p12", "photo-1473116763249-2faaef81ccda")
    ].map { id, photoID in
        MomentSingleMoment.Media(
            id: id,
            url: URL(string: "https://images.unsplash.com/\(photoID)?auto=format&fit=crop&w=900&q=85")!,
            previewURL: URL(string: "https://images.unsplash.com/\(photoID)?auto=format&fit=crop&w=360&q=40")!
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("朋友圈").font(.system(size: 27, weight: .bold))
                        Spacer()
                        Image(systemName: "camera").font(.system(size: 20, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                    MomentSingleMoment(
                        model: .init(
                            author: author,
                            text: "逃离城市一会儿，去山里收集一点风和日落。\n生活偶尔需要慢下来 🌿",
                            media: photos,
                            createdAt: .now.addingTimeInterval(-3600 * 2),
                            location: "莫干山",
                            isLikedByCurrentUser: liked,
                            likes: likes,
                            comments: comments
                        ),
                        onToggleLike: { value in
                            liked = value
                            if value {
                                if !likes.contains(where: { $0.id == "me" }) { likes.append(.init(id: "me", name: "我")) }
                            } else {
                                likes.removeAll { $0.id == "me" }
                            }
                        },
                        onComment: { text in
                            comments.append(.init(author: .init(id: "me", name: "我"), text: text, createdAt: .now))
                        }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Label("演示说明", systemImage: "hand.tap")
                            .font(.system(size: 14, weight: .semibold))
                        Text("在时间和位置同一行的右侧点击「···」尝试点赞、取消赞或评论。点赞列表和评论列表直接显示在动态下方；点图片可查看大图。这里使用本地演示状态，不会发送真实请求。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(16)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
