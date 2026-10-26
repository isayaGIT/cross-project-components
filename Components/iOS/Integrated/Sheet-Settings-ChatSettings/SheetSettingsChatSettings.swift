import SwiftUI

/// A minimal global-settings placeholder. Provider credentials are configured by the host application.
public struct SheetSettingsChatSettings: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("全局设置")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Text("模型服务商、API 地址与 API Key")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Text("角色使用的模型与说话方式由角色配置管理。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("全局设置") {
    OverlayPresenter(isPresented: .constant(true)) {
        SheetSettingsChatSettings()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
