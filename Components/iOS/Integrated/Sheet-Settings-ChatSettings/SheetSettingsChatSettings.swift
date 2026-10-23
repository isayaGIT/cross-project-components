import SwiftUI

/// A minimal chat-settings sheet. Additional settings can be added here later.
public struct SheetSettingsChatSettings: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("聊天设置")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("聊天设置") {
    SheetCustom(isPresented: .constant(true)) {
        SheetSettingsChatSettings()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
