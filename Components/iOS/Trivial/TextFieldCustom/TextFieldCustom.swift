import SwiftUI
#if canImport(BackgroundData)
import BackgroundData
#endif

/// A reusable text field with configurable shape, fill, typography, and optional border.
public struct TextFieldCustom: View {
    public enum ShapeStyle {
        case rectangle
        case roundedRectangle(CGFloat)
        case capsule
    }

    @Binding private var text: String
    private let placeholder: String
    private let font: Font
    private let foreground: Color
    private let background: AnyView
    private let shape: ShapeStyle
    private let borderLine: AnyView?
    private let submitLabel: SubmitLabel
    private let minHeight: CGFloat
    private let onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        font: Font = .system(size: 16),
        foreground: Color = .primary,
        background: AnyView = AnyView(Color.primary.opacity(0.06)),
        shape: ShapeStyle = .roundedRectangle(14),
        borderLine: AnyView? = nil,
        submitLabel: SubmitLabel = .search,
        minHeight: CGFloat = 48,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.foreground = foreground
        self.background = background
        self.shape = shape
        self.borderLine = borderLine
        self.submitLabel = submitLabel
        self.minHeight = max(0, minHeight)
        self.onSubmit = onSubmit
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .font(font)
            .foregroundStyle(foreground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .background { background.clipShape(resolvedShape) }
            .overlay {
                if let borderLine { borderLine.allowsHitTesting(false) }
            }
    }

    private var resolvedShape: AnyShape {
        switch shape {
        case .rectangle: AnyShape(Rectangle())
        case .roundedRectangle(let radius): AnyShape(RoundedRectangle(cornerRadius: max(0, radius), style: .continuous))
        case .capsule: AnyShape(Capsule())
        }
    }
}
