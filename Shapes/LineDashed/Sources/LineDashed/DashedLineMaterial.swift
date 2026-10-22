import SwiftUI

/// System material choices are kept separate from ordinary fills because availability differs by OS.
public enum DashedLineMaterial {
    case ultraThin
    case thin
    case regular
    case thick
    case ultraThick

    @available(iOS 26.0, macOS 26.0, *)
    public enum Glass {
        case regular
        case clear
    }
}
