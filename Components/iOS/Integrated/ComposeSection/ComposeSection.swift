import SwiftUI
import BottomSheet

/// A text capsule and the optional view shown when the capsule is swiped upward.
public struct ComposeCapsule: Identifiable {
    public let id: String
    public var title: String
    public var sheetContent: AnyView?

    public init<ID: StringProtocol>(id: ID? = nil, title: String, sheetContent: AnyView? = nil) {
        self.id = id.map { String($0) } ?? title
        self.title = title
        self.sheetContent = sheetContent
    }

    public init<Content: View>(id: String? = nil, title: String, @ViewBuilder sheetContent: () -> Content) {
        self.id = id ?? title
        self.title = title
        self.sheetContent = AnyView(sheetContent())
    }
}

/// Horizontally scrolling selectable capsules above the existing input bar.
/// Capsule actions and meaning remain the responsibility of the caller.
public struct ComposeSection<Input: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIDs: Set<String> = []
    @State private var activeSheetCapsule: ComposeCapsule?
    @State private var sheetPosition: BottomSheetPosition = .hidden
    @State private var upwardDrag: CGFloat = 0

    private let capsules: [ComposeCapsule]
    private let capsuleSpacing: CGFloat
    private let horizontalPadding: CGFloat
    private let messageBottomSpacing: CGFloat
    private let input: Input

    public init(
        capsules: [ComposeCapsule] = [],
        capsuleSpacing: CGFloat = 8,
        horizontalPadding: CGFloat = 12,
        messageBottomSpacing: CGFloat = 8,
        @ViewBuilder input: () -> Input
    ) {
        self.capsules = capsules
        self.capsuleSpacing = max(0, capsuleSpacing)
        self.horizontalPadding = max(0, horizontalPadding)
        self.messageBottomSpacing = max(0, messageBottomSpacing)
        self.input = input()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !capsules.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: capsuleSpacing) {
                        ForEach(capsules) { capsule in
                            capsuleView(capsule)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, horizontalPadding)
                }
                .scrollIndicators(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            }

            input
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 7)
        }
        .padding(.top, messageBottomSpacing)
        // Keep the section transparent: the input's capsule is the only composer surface.
        .overlay {
            if let activeCapsule = activeSheetCapsule, let sheetContent = activeCapsule.sheetContent {
                Color.clear
                    .bottomSheet(
                        bottomSheetPosition: $sheetPosition,
                        switchablePositions: [.hidden, .relative(0.62)],
                        content: { sheetContent }
                    )
                    .showDragIndicator(true)
                    .enableTapToDismiss(true)
                    .enableSwipeToDismiss(true)
                    .onChange(of: activeCapsule.id) { _, _ in
                        sheetPosition = .relative(0.62)
                    }
                    .onChange(of: sheetPosition) { _, position in
                        if case .hidden = position {
                            activeSheetCapsule = nil
                        }
                    }
            }
        }
    }

    private func capsuleView(_ capsule: ComposeCapsule) -> some View {
        let selected = selectedIDs.contains(capsule.id)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if selected { selectedIDs.remove(capsule.id) }
                else { selectedIDs.insert(capsule.id) }
            }
        } label: {
            Text(capsule.title)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(selected ? Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.13) : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                }
                .overlay {
                    Capsule().strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.07), lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in upwardDrag = value.translation.height }
                .onEnded { value in
                    let shouldOpen = value.translation.height < -24 || value.predictedEndTranslation.height < -40
                    upwardDrag = 0
                    if shouldOpen, capsule.sheetContent != nil {
                        activeSheetCapsule = capsule
                    }
                }
        )
        .accessibilityHint(capsule.sheetContent == nil ? "Tap to toggle selection" : "Swipe up for more")
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { activeSheetCapsule != nil },
            set: {
                if !$0 {
                    activeSheetCapsule = nil
                    sheetPosition = .hidden
                } else {
                    sheetPosition = .relative(0.62)
                }
            }
        )
    }
}
