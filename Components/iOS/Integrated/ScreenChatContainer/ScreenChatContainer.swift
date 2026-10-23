import SwiftUI

/// A reusable shell that reveals a leading sidebar by shifting its content as one layer.
///
/// This component intentionally knows nothing about chat models, headers, or sidebar rows.
/// Supply those as views so the container can be reused with different feature components.
public struct ScreenChatContainer<Sidebar: View, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSidebarOpen = false

    private let sidebarWidth: CGFloat
    private let sidebar: (@escaping () -> Void) -> Sidebar
    private let content: (@escaping () -> Void) -> Content

    /// - Parameters:
    ///   - sidebarWidth: Preferred sidebar width, capped at 82% of the available width.
    ///   - sidebar: The sidebar view shown underneath the moving content.
    ///   - content: The foreground view builder. Its callback toggles the sidebar open/closed.
    public init(
        sidebarWidth: CGFloat = 300,
        @ViewBuilder sidebar: @escaping (@escaping () -> Void) -> Sidebar,
        @ViewBuilder content: @escaping (@escaping () -> Void) -> Content
    ) {
        self.sidebarWidth = max(0, sidebarWidth)
        self.sidebar = sidebar
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            let revealWidth = min(sidebarWidth, geometry.size.width * 0.82)

            ZStack(alignment: .leading) {
                sidebar(closeSidebar)
                    .frame(width: revealWidth, height: geometry.size.height, alignment: .topLeading)
                    .accessibilityHidden(!isSidebarOpen)

                content(toggleSidebar)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(isSidebarOpen ? 0.16 : 0), radius: 16, x: -4, y: 0)
                    .offset(x: isSidebarOpen ? revealWidth : 0)
                    // While the sidebar is open, taps on the exposed chat area only dismiss
                    // the sidebar; they must not activate controls underneath this layer.
                    .overlay {
                        if isSidebarOpen {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture(perform: closeSidebar)
                        }
                    }
                    .accessibilityAction(named: Text("切换聊天列表"), toggleSidebar)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .animation(
                reduceMotion ? .easeInOut(duration: 0.01) : .spring(response: 0.36, dampingFraction: 0.88),
                value: isSidebarOpen
            )
        }
    }

    private func toggleSidebar() {
        isSidebarOpen.toggle()
    }

    private func closeSidebar() {
        isSidebarOpen = false
    }
}
