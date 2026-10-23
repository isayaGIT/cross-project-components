import SwiftUI

/// A compact routing row that pairs a task with its selected LLM provider and model.
///
/// The host application owns route selection and persistence. This view only renders
/// the supplied values and optionally forwards taps.
public struct ListNodeLlmRoute: View {
    private let taskIcon: Image
    private let taskIconColor: Color
    private let taskText: String
    private let taskFont: Font?
    private let taskFontSize: CGFloat
    private let taskFontColor: Color

    private let llmIcon: Image
    private let llmIconColor: Color
    private let llmName: String
    private let llmNameFont: Font?
    private let llmNameFontSize: CGFloat
    private let llmNameColor: Color
    private let llmModelName: String
    private let llmModelFont: Font?
    private let llmModelFontSize: CGFloat
    private let llmModelColor: Color

    private let onTap: (() -> Void)?

    public init(
        taskIcon: Image,
        taskIconColor: Color = .secondary,
        taskText: String,
        taskFont: Font? = nil,
        taskFontSize: CGFloat = 15,
        taskFontColor: Color = .primary,
        llmIcon: Image,
        llmIconColor: Color = .primary,
        llmName: String,
        llmNameFont: Font? = nil,
        llmNameFontSize: CGFloat = 14,
        llmNameColor: Color = .primary,
        llmModelName: String,
        llmModelFont: Font? = nil,
        llmModelFontSize: CGFloat = 12,
        llmModelColor: Color = .secondary,
        onTap: (() -> Void)? = nil
    ) {
        self.taskIcon = taskIcon
        self.taskIconColor = taskIconColor
        self.taskText = taskText
        self.taskFont = taskFont
        self.taskFontSize = Self.validFontSize(taskFontSize, fallback: 15)
        self.taskFontColor = taskFontColor
        self.llmIcon = llmIcon
        self.llmIconColor = llmIconColor
        self.llmName = llmName
        self.llmNameFont = llmNameFont
        self.llmNameFontSize = Self.validFontSize(llmNameFontSize, fallback: 14)
        self.llmNameColor = llmNameColor
        self.llmModelName = llmModelName
        self.llmModelFont = llmModelFont
        self.llmModelFontSize = Self.validFontSize(llmModelFontSize, fallback: 12)
        self.llmModelColor = llmModelColor
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityHint("编辑此任务的模型路由")
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            taskIcon
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(taskIconColor)
                .accessibilityHidden(true)

            Text(taskText)
                .font(taskFont ?? .system(size: taskFontSize, weight: .medium))
                .foregroundStyle(taskFontColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                Text(llmName)
                    .font(llmNameFont ?? .system(size: llmNameFontSize, weight: .medium))
                    .foregroundStyle(llmNameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(llmModelName)
                    .font(llmModelFont ?? .system(size: llmModelFontSize))
                    .foregroundStyle(llmModelColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 180, alignment: .trailing)
            .layoutPriority(1)

            llmIcon
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(llmIconColor)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(taskText)，\(llmName)，模型 \(llmModelName)")
    }

    private static func validFontSize(_ size: CGFloat, fallback: CGFloat) -> CGFloat {
        size.isFinite ? max(1, size) : fallback
    }
}

#Preview("LLM Route") {
    VStack(spacing: 0) {
        ListNodeLlmRoute(
            taskIcon: Image(systemName: "bubble.left.and.bubble.right"),
            taskIconColor: .blue,
            taskText: "聊天回复",
            llmIcon: Image(systemName: "sparkles"),
            llmIconColor: .purple,
            llmName: "OpenAI",
            llmModelName: "GPT-5.2",
            onTap: {}
        )
        Divider().padding(.leading, 16)
        ListNodeLlmRoute(
            taskIcon: Image(systemName: "text.alignleft"),
            taskIconColor: .orange,
            taskText: "长文本总结",
            llmIcon: Image(systemName: "brain.head.profile"),
            llmIconColor: .indigo,
            llmName: "Anthropic",
            llmModelName: "Claude Sonnet 4.5"
        )
        Divider().padding(.leading, 16)
        ListNodeLlmRoute(
            taskIcon: Image(systemName: "photo"),
            taskIconColor: .pink,
            taskText: "图像理解",
            llmIcon: Image(systemName: "network"),
            llmName: "Google",
            llmModelName: "Gemini 2.5 Pro"
        )
    }
    .background(Color.primary.opacity(0.035))
}
