import ScreenMiniature
import SwiftUI

@MainActor
private final class DemoChatModel: ObservableObject {
    @Published var messages = [
        "Hey! Did you see the new place?",
        "I did — the light there is lovely ✨",
        "We should go together this weekend."
    ]
    @Published var unreadCount = 2

    func sendMessage() {
        messages.append("Added just now · \(messages.count + 1)")
        unreadCount += 1
    }
}

struct ScreenMiniatureDemoView: View {
    @StateObject private var model = DemoChatModel()
    private let sourceSize = CGSize(width: 260, height: 540)
    private let miniatureSize = CGSize(width: 104, height: 216)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMPONENT LAB")
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(.indigo)
                    Text("Screen Miniature")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("A non-interactive scaled preview that follows the same live model as its source screen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        label("SOURCE SCREEN", detail: "Interactive")
                        MiniChatScreen(model: model)
                            .frame(width: sourceSize.width, height: sourceSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(.black.opacity(0.10), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("MINIATURE", detail: "Read-only")
                        ScreenMiniature(sourceSize: sourceSize, size: miniatureSize) {
                            MiniChatScreen(model: model)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.indigo.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
                        Text("Tap Send on the source. The miniature updates, but cannot be tapped itself.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: miniatureSize.width, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Live-state check")
                            .font(.subheadline.weight(.semibold))
                        Text("\(model.messages.count) messages · \(model.unreadCount) unread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Send") { model.sendMessage() }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .accessibilityIdentifier("send-source-message")
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }

                Text("Implementation note: this first experiment scales a SwiftUI view and disables hit testing. It re-renders the supplied content; it does not mirror an existing window instance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func label(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MiniChatScreen: View {
    @ObservedObject var model: DemoChatModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Circle()
                    .fill(LinearGradient(colors: [.pink, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mia")
                        .font(.system(size: 12, weight: .semibold))
                    Text("online")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                }
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(.white.opacity(0.96))

            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)

            ScrollView {
                VStack(spacing: 12) {
                    Text("TODAY  9:41 AM")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    ForEach(Array(model.messages.enumerated()), id: \.offset) { index, message in
                        HStack {
                            if index.isMultiple(of: 2) { Spacer(minLength: 22) }
                            Text(message)
                                .font(.system(size: 10))
                                .foregroundStyle(index.isMultiple(of: 2) ? .white : Color.primary.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(index.isMultiple(of: 2) ? Color.indigo : Color.white)
                                }
                            if !index.isMultiple(of: 2) { Spacer(minLength: 22) }
                        }
                    }
                    HStack {
                        Text("\(model.unreadCount) new")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.indigo.opacity(0.08), in: Capsule())
                        Spacer()
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.indigo)
                Text("Message…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(action: model.sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mini-chat-send")
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(.white)
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.99))
        .frame(width: 260, height: 540)
        .clipped()
    }
}
