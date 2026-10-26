import SwiftUI

/// Shape options for a canvas node control.
public enum CanvasNodeButtonShape {
    case circle
    case roundedRectangle
    case rectangle
}

/// A single control that supports click and/or drag callbacks.
public struct CanvasNodeButton: View {
    public var icon: String
    public var size: CGFloat
    public var shape: CanvasNodeButtonShape
    public var width: CGFloat?
    public var height: CGFloat?
    public var tint: Color
    public var onClick: (() -> Void)?
    public var onDrag: ((CGSize) -> Void)?
    @State private var dragTranslation = CGSize.zero

    public init(
        icon: String,
        size: CGFloat = 26,
        shape: CanvasNodeButtonShape = .circle,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        tint: Color = .white,
        onClick: (() -> Void)? = nil,
        onDrag: ((CGSize) -> Void)? = nil
    ) {
        self.icon = icon
        self.size = max(1, size)
        self.shape = shape
        self.width = width
        self.height = height
        self.tint = tint
        self.onClick = onClick
        self.onDrag = onDrag
    }

    public var body: some View {
        Group {
            if let onClick {
                Button(action: onClick) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .frame(width: max(1, width ?? size), height: max(1, height ?? size))
        .contentShape(Rectangle())
        .gesture(dragGesture, including: onDrag == nil ? .none : .all)
        .accessibilityLabel(icon)
    }

    private var label: some View {
        ZStack {
            backgroundShape.fill(Color.black.opacity(0.78))
            backgroundShape.stroke(Color.white.opacity(0.16), lineWidth: 0.7)
            Image(systemName: icon)
                .font(.system(size: max(8, size * 0.42), weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: max(1, width ?? size), height: max(1, height ?? size))
    }

    private var backgroundShape: AnyShape {
        switch shape {
        case .circle: AnyShape(Circle())
        case .roundedRectangle: AnyShape(RoundedRectangle(cornerRadius: min(size * 0.25, 6)))
        case .rectangle: AnyShape(Rectangle())
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard onDrag != nil else { return }
                let delta = DragCore.incrementalDelta(from: dragTranslation, to: value.translation)
                dragTranslation = value.translation
                if delta != .zero { onDrag?(delta) }
            }
            .onEnded { _ in
                dragTranslation = .zero
            }
    }
}

/// Standard controls anchored independently to a node's selection bounds.
/// The host owns model mutations; drag callbacks receive incremental deltas.
public struct CanvasNodeButtons: View {
    public var buttonSize: CGFloat
    public var spacing: CGFloat
    public var selectionWidth: CGFloat
    public var selectionHeight: CGFloat
    public var onDelete: (() -> Void)?
    public var onResize: ((CGSize) -> Void)?
    public var onRotate: ((CGSize) -> Void)?

    public init(
        buttonSize: CGFloat = 26,
        spacing: CGFloat = 5,
        selectionWidth: CGFloat,
        selectionHeight: CGFloat,
        onDelete: (() -> Void)? = nil,
        onResize: ((CGSize) -> Void)? = nil,
        onRotate: ((CGSize) -> Void)? = nil
    ) {
        self.buttonSize = max(1, buttonSize)
        self.spacing = max(0, spacing)
        self.selectionWidth = max(0, selectionWidth)
        self.selectionHeight = max(0, selectionHeight)
        self.onDelete = onDelete
        self.onResize = onResize
        self.onRotate = onRotate
    }

    public var body: some View {
        Color.clear
            .frame(width: selectionWidth, height: selectionHeight)
            .overlay(alignment: .top) {
                if let onRotate {
                    CanvasNodeButton(icon: "rotate.right", size: buttonSize, tint: .white, onDrag: onRotate)
                        .help("Drag to rotate")
                        .offset(y: -buttonSize / 2)
                        .zIndex(1)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let onDelete {
                    CanvasNodeButton(icon: "xmark", size: buttonSize, tint: .white, onClick: onDelete)
                        .help("Delete node")
                        .offset(x: buttonSize / 2, y: -buttonSize / 2)
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let onResize {
                    CanvasNodeButton(icon: "arrow.up.left.and.arrow.down.right", size: buttonSize, tint: .white, onDrag: onResize)
                        .help("Drag to resize")
                        .offset(x: buttonSize / 2, y: buttonSize / 2)
                        .zIndex(1)
                }
            }
            .fixedSize()
    }
}
