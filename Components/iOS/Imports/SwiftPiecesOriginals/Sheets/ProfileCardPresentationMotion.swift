import SwiftUI

/// Presentation motion adapted from Swift Pieces' PieceMotion language.
/// The reveal/dismiss timing follows its `calm` and `dismiss` roles.
/// Keep presentation choreography outside ProfileCard so the card remains a static reusable view.
public enum SwiftPiecesProfileCardMotion {
    public static func reveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.2)
    }

    public static func dismiss(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeIn(duration: 0.18) : .spring(duration: 0.3, bounce: 0.08)
    }

    public static func insertion(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
    }

    public static func removal(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .center).combined(with: .opacity)
    }
}
