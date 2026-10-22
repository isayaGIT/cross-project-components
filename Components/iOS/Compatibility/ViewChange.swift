import SwiftUI

/// Uses the modern two-value `onChange` API where available and preserves the
/// single-value API for the macOS 13 compatibility build of this package.
struct CompatibleOnChange<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            content.onChange(of: value, perform: action)
        }
    }
}

extension View {
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        modifier(CompatibleOnChange(value: value, action: action))
    }
}
