import SwiftUI
#if canImport(UIKit)
import UIKit
#if canImport(LiquidGlassKit)
import LiquidGlassKit
#endif
#endif

/// A tab item displayed by `TabBar`.
public struct TabBarItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

/// The visual texture used for the tab bar's capsule.
public enum TabBarTexture: Equatable {
    /// Uses SwiftUI's built-in material and works without LiquidGlassKit.
    case material
    /// Uses LiquidGlassKit's backported/native glass effect when available.
    case liquidGlass
}

/// A compact, reusable tab bar with an animated selection capsule.
///
/// The component supports one through six items. Its default texture is ordinary
/// system material; Liquid Glass is opt-in and does not raise the component's
/// minimum iOS version.
public struct TabBar: View {
    private let items: [TabBarItem]
    @Binding private var selection: String
    private let texture: TabBarTexture
    private let height: CGFloat
    private let gradientHeight: CGFloat
    private let onSelect: ((TabBarItem) -> Void)?

    @Namespace private var selectionNamespace

    public init(
        items: [TabBarItem],
        selection: Binding<String>,
        texture: TabBarTexture = .material,
        height: CGFloat = 42,
        gradientHeight: CGFloat = 108,
        onSelect: ((TabBarItem) -> Void)? = nil
    ) {
        precondition((1...6).contains(items.count), "TabBar supports between one and six items.")
        precondition(Set(items.map(\.id)).count == items.count, "TabBar item IDs must be unique.")
        self.items = items
        self._selection = selection
        self.texture = texture
        self.height = max(40, height)
        self.gradientHeight = max(0, gradientHeight)
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(5)
        .frame(height: height)
        .background {
            Capsule(style: .continuous)
                .fill(.clear)
                .background {
                    TabBarTextureBackground(texture: texture)
                        .clipShape(Capsule(style: .continuous))
                }
                .overlay {
                    if texture == .material {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                    }
                }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ item: TabBarItem) -> some View {
        let isSelected = selection == item.id

        return Button {
            guard selection != item.id else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.08)) {
                selection = item.id
            }
            onSelect?(item)
        } label: {
            ZStack {
                // Keep the animated selection capsule in its own background layer.
                // matchedGeometryEffect preserves the same spring movement between tabs.
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(selectionFill)
                        .matchedGeometryEffect(id: "tabbar.selection", in: selectionNamespace)
                        .padding(1)
                }

                // Draw labels and symbols above the glass/selection layers so they stay crisp.
                VStack(spacing: 1) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .symbolVariant(isSelected ? .fill : .none)
                        .frame(width: 20, height: 20)
                        .symbolEffect(.bounce, value: isSelected)
                    Text(item.title)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectionFill: AnyShapeStyle {
        switch texture {
        case .material:
            AnyShapeStyle(.regularMaterial)
        case .liquidGlass:
            AnyShapeStyle(Color.primary.opacity(0.10))
        }
    }
}


private struct TabBarTextureBackground: View {
    let texture: TabBarTexture

    var body: some View {
        Group {
            switch texture {
            case .material:
                Capsule(style: .continuous).fill(.regularMaterial)
            case .liquidGlass:
                liquidGlassBackground
            }
        }
    }

    @ViewBuilder
    private var liquidGlassBackground: some View {
        #if canImport(UIKit) && canImport(LiquidGlassKit)
        LiquidGlassEffectRepresentable()
        #else
        // Keep the component usable if LiquidGlassKit is not linked on this platform.
        Capsule(style: .continuous).fill(.regularMaterial)
        #endif
    }
}

#if canImport(UIKit) && canImport(LiquidGlassKit)
private struct LiquidGlassEffectRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let effectView = LiquidGlassEffectView(effect: LiquidGlassEffect(style: .regular, isNative: false))
        effectView.isUserInteractionEnabled = false
        effectView.backgroundColor = UIColor.clear
        return effectView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
