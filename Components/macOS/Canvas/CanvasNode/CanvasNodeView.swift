import SwiftUI

/// A reusable canvas node that owns selection hit-testing and zoom-aware dragging.
/// The host supplies its artwork and remains responsible for mutating its document model.
public struct CanvasNodeView<NodeID: Hashable, Content: View>: View {
    public let id: NodeID
    public let position: CGPoint
    public let hitSize: CGSize
    public let selectionSize: CGSize
    public let zoom: CGFloat
    public let isSelected: Bool
    public let selectionRotation: Double
    public var selectionColor: Color
    public var selectionLineLength: CGFloat
    public var selectionLineSpacing: CGFloat
    public var selectionLineWeight: CGFloat
    public var onDelete: (() -> Void)?
    public var onResize: ((CGSize) -> Void)?
    public var onRotate: ((CGSize) -> Void)?
    public var onSelect: (NodeID) -> Void
    public var onPositionChange: (CGPoint) -> Void
    private let content: Content

    @State private var dragStart: CGPoint?

    public init(
        id: NodeID,
        position: CGPoint,
        hitSize: CGSize,
        selectionSize: CGSize? = nil,
        zoom: CGFloat = 1,
        isSelected: Bool = false,
        selectionRotation: Double = 0,
        selectionColor: Color = Color(red: 0.95, green: 0.46, blue: 0.83),
        selectionLineLength: CGFloat = 4,
        selectionLineSpacing: CGFloat = 3,
        selectionLineWeight: CGFloat = 1,
        onDelete: (() -> Void)? = nil,
        onResize: ((CGSize) -> Void)? = nil,
        onRotate: ((CGSize) -> Void)? = nil,
        onSelect: @escaping (NodeID) -> Void,
        onPositionChange: @escaping (CGPoint) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.position = position
        self.hitSize = hitSize
        self.selectionSize = selectionSize ?? hitSize
        self.zoom = max(0.01, zoom)
        self.isSelected = isSelected
        self.selectionRotation = selectionRotation
        self.selectionColor = selectionColor
        self.selectionLineLength = max(0, selectionLineLength)
        self.selectionLineSpacing = max(0, selectionLineSpacing)
        self.selectionLineWeight = max(0, selectionLineWeight)
        self.onDelete = onDelete
        self.onResize = onResize
        self.onRotate = onRotate
        self.onSelect = onSelect
        self.onPositionChange = onPositionChange
        self.content = content()
    }

    public var body: some View {
        content
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: hitSize.width, height: hitSize.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let moved = hypot(value.translation.width, value.translation.height) > 4
                                guard moved else { return }
                                if dragStart == nil {
                                    dragStart = position
                                    onSelect(id)
                                }
                                guard let start = dragStart else { return }
                                onPositionChange(DragCore.translated(start, by: value.translation, scale: zoom))
                            }
                            .onEnded { value in
                                let moved = hypot(value.translation.width, value.translation.height) > 4
                                if !moved { onSelect(id) }
                                dragStart = nil
                            }
                    )
            }
            .overlay {
                if isSelected {
                    CanvasNodeSelectionBorder(
                        color: selectionColor,
                        lineLength: selectionLineLength,
                        lineSpacing: selectionLineSpacing,
                        weight: selectionLineWeight,
                        width: selectionSize.width,
                        height: selectionSize.height
                    )
                    .rotationEffect(.degrees(selectionRotation))
                }
            }
            .overlay(alignment: .center) {
                if isSelected && (onDelete != nil || onResize != nil || onRotate != nil) {
                    CanvasNodeButtons(
                        selectionWidth: selectionSize.width,
                        selectionHeight: selectionSize.height,
                        onDelete: onDelete,
                        onResize: onResize,
                        onRotate: onRotate
                    )
                    .rotationEffect(.degrees(selectionRotation))
                    .zIndex(2)
                }
            }
    }
}
