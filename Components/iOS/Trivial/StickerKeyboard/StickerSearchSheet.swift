import SwiftUI
#if STICKER_KEYBOARD_STANDALONE
import CrossProjectComponentsIOS
#endif

/// Search entry point for the app-wide sticker catalogue. Connect `onSearch` to the
/// host's catalogue service; this view intentionally does not search installed packs.
public struct StickerSearchSheet: View {
    public struct Configuration {
        public var sheet: SheetCustomConfiguration
        public var titleColor: Color
        public var secondaryTextColor: Color
        public var inputBackground: Color
        public var recommendations: [String]

        public init(
            sheet: SheetCustomConfiguration = .init(height: .fraction(0.58)),
            titleColor: Color = .primary,
            secondaryTextColor: Color = .secondary,
            inputBackground: Color = Color.primary.opacity(0.06),
            recommendations: [String] = ["Happy", "Cute", "Good morning", "Thank you", "Love", "Celebration"]
        ) {
            self.sheet = sheet
            self.titleColor = titleColor
            self.secondaryTextColor = secondaryTextColor
            self.inputBackground = inputBackground
            self.recommendations = recommendations
        }
    }

    @Binding private var isPresented: Bool
    private let configuration: Configuration
    private let onSearch: (String) -> Void
    @State private var query = ""
    @FocusState private var isInputFocused: Bool

    public init(
        isPresented: Binding<Bool>,
        configuration: Configuration = .init(),
        onSearch: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.configuration = configuration
        self.onSearch = onSearch
    }

    public var body: some View {
        ZStack {
            Color.clear
            if isPresented {
                SheetCustom(isPresented: $isPresented, configuration: configuration.sheet) {
                    searchContent
                }
            }
        }
        .onChange(of: isPresented) { presented in
            if !presented { isInputFocused = false }
        }
    }

    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Search stickers")
                        .font(.system(size: 24, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(configuration.titleColor)
                    Text("Discover something to express yourself")
                        .font(.system(size: 14))
                        .foregroundStyle(configuration.secondaryTextColor)
                }
                Spacer(minLength: 0)
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(configuration.secondaryTextColor)
                        .frame(width: 32, height: 32)
                        .background(configuration.inputBackground, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close sticker search")
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 14) {
                Text("RECOMMENDED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(configuration.secondaryTextColor)
                FlowLayout(spacing: 9) {
                    ForEach(configuration.recommendations, id: \.self) { term in
                        CapsuleButton(
                            term,
                            background: configuration.inputBackground,
                            foreground: configuration.titleColor,
                            cornerRadius: 15,
                            padding: EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15),
                            font: .system(size: 14, weight: .medium)
                        ) {
                            query = term
                            submit(term)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)

            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(configuration.secondaryTextColor)
                TextField("Search the sticker library", text: $query)
                    .font(.system(size: 16))
                    .foregroundStyle(configuration.titleColor)
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    #endif
                    .focused($isInputFocused)
                    .onSubmit { submit(query) }
                if !query.isEmpty {
                    Button {
                        query = ""
                        isInputFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(configuration.secondaryTextColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(configuration.inputBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func submit(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSearch(value)
    }
}

/// A small wrapping layout for recommendation chips without an extra dependency.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > limit {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(limit, proposal.width ?? x), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
