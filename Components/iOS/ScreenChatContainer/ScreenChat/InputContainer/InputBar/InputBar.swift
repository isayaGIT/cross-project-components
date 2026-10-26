import SwiftUI

/// The visual capsule behind the chat composer controls.
///
/// Controls and their interaction state are owned by `InputContainer`; this view
/// is intentionally limited to the shared capsule surface.
public struct InputBar: View {
    private let background: Color?
    private let usesGlass: Bool

    public init(background: Color? = nil, usesGlass: Bool = false) {
        self.background = background
        self.usesGlass = usesGlass
    }

    public var body: some View {
        Group {
            if usesGlass {
                // Use the native material as the surface itself; do not tint the glass.
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.72), lineWidth: 1))
            } else {
                Capsule()
                    .fill(background ?? Color.clear)
                    .background {
                        if background == nil {
                            if #available(iOS 26.0, *) {
                                Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
                            } else {
                                Capsule().fill(.regularMaterial)
                            }
                        }
                    }
            }
        }
            .shadow(color: .black.opacity(usesGlass ? 0.045 : 0.07), radius: usesGlass ? 12 : 7, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}
