import ScreenMiniature
import SwiftUI

private enum RouteTask: String, CaseIterable, Identifiable {
    case chat = "Chat response"
    case research = "Web research"
    case summary = "Conversation summary"
    case coding = "Code assistant"
    case memory = "Memory extraction"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right.fill"
        case .research: "sparkle.magnifyingglass"
        case .summary: "text.alignleft"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .memory: "brain.head.profile"
        }
    }
    var tint: Color {
        switch self {
        case .chat: Color(red: 0.55, green: 0.47, blue: 0.88)
        case .research: Color(red: 0.32, green: 0.64, blue: 0.80)
        case .summary: Color(red: 0.91, green: 0.57, blue: 0.68)
        case .coding: Color(red: 0.35, green: 0.67, blue: 0.58)
        case .memory: Color(red: 0.88, green: 0.65, blue: 0.37)
        }
    }
    var subtitle: String {
        switch self {
        case .chat: "Live conversation"
        case .research: "Search and synthesis"
        case .summary: "Long-context digest"
        case .coding: "Code generation"
        case .memory: "Personal memory"
        }
    }
}

private struct LLMProvider: Identifiable, Equatable {
    let name: String
    let model: String
    let mark: String
    let tint: Color
    var id: String { name }

    static let choices: [LLMProvider] = [
        .init(name: "OpenAI", model: "GPT-5.2", mark: "✳", tint: Color(red: 0.12, green: 0.52, blue: 0.42)),
        .init(name: "Anthropic", model: "Claude Sonnet 4.5", mark: "✳", tint: Color(red: 0.76, green: 0.43, blue: 0.29)),
        .init(name: "Google", model: "Gemini 2.5 Pro", mark: "✦", tint: Color(red: 0.31, green: 0.48, blue: 0.88)),
        .init(name: "DeepSeek", model: "DeepSeek V3", mark: "◈", tint: Color(red: 0.29, green: 0.52, blue: 0.88))
    ]
}

private struct RouteConfiguration: Identifiable {
    let task: RouteTask
    var provider: LLMProvider
    var id: String { task.id }
}

struct LLMRoutesDemoView: View {
    @State private var selectedTask: RouteTask = .chat
    @State private var carouselPosition: String? = RouteTask.chat.id
    @State private var routes: [RouteConfiguration] = [
        .init(task: .chat, provider: LLMProvider.choices[0]),
        .init(task: .research, provider: LLMProvider.choices[2]),
        .init(task: .summary, provider: LLMProvider.choices[1]),
        .init(task: .coding, provider: LLMProvider.choices[0]),
        .init(task: .memory, provider: LLMProvider.choices[3])
    ]
    @State private var editingTask: RouteTask?
    @Namespace private var carouselNamespace

    private let ink = Color(red: 0.18, green: 0.17, blue: 0.24)
    private let muted = Color(red: 0.53, green: 0.51, blue: 0.60)
    private let canvas = Color(red: 0.965, green: 0.958, blue: 0.985)

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeading("Screens", detail: "Choose a task to configure")
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    screenCarousel
                        .padding(.bottom, 17)

                    HStack(alignment: .firstTextBaseline) {
                        Text("LLM routes")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .tracking(-0.55)
                            .foregroundStyle(ink)
                        Spacer()
                        Text("\(routes.count) TASKS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.15)
                            .foregroundStyle(muted)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            routeRow(route)
                            if index < routes.count - 1 {
                                Rectangle()
                                    .fill(Color(red: 0.91, green: 0.89, blue: 0.94))
                                    .frame(height: 1)
                                    .padding(.leading, 68)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 0.43, green: 0.35, blue: 0.63).opacity(0.055), radius: 24, x: 0, y: 10)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Each task can use its own model")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 22)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack(alignment: .topTrailing) {
                canvas
                Circle()
                    .fill(Color(red: 0.87, green: 0.82, blue: 0.99).opacity(0.25))
                    .frame(width: 270, height: 270)
                    .blur(radius: 55)
                    .offset(x: 100, y: -70)
                Circle()
                    .fill(Color(red: 0.97, green: 0.84, blue: 0.90).opacity(0.22))
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .offset(x: -160, y: 300)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .sheet(item: $editingTask) { task in
            providerPicker(for: task)
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LLM Routes")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-1.0)
                    .foregroundStyle(ink)
                Text("One model for every kind of work.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(muted)
            }
            Spacer(minLength: 4)
            Button {} label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.39, green: 0.35, blue: 0.51))
                    .frame(width: 45, height: 45)
                    .background(.white.opacity(0.85), in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.035), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Route settings")
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(-0.35)
                .foregroundStyle(ink)
            Spacer()
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(muted)
        }
    }

    private var screenCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 13) {
                    ForEach(RouteTask.allCases) { task in
                        screenCard(task)
                            .id(task.id)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.91)
                                    .opacity(phase.isIdentity ? 1 : 0.76)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 28)
                .padding(.vertical, 5)
            }
            .contentMargins(.zero, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $carouselPosition, anchor: .center)
            .onChange(of: selectedTask) { _, task in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    carouselPosition = task.id
                    proxy.scrollTo(task.id, anchor: .center)
                }
            }
            .onChange(of: carouselPosition) { _, taskID in
                guard let taskID, let task = RouteTask.allCases.first(where: { $0.id == taskID }) else { return }
                if selectedTask != task {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedTask = task
                    }
                }
            }
        }
        .frame(height: 260)
    }

    private func screenCard(_ task: RouteTask) -> some View {
        let isSelected = selectedTask == task
        return Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                selectedTask = task
            }
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(red: 0.975, green: 0.968, blue: 0.995)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    ScreenMiniature(sourceSize: CGSize(width: 390, height: 844), size: CGSize(width: 126, height: 246)) {
                        taskPreview(task)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.045), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 0.26, green: 0.21, blue: 0.39).opacity(0.13), radius: 12, x: 0, y: 7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 36)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 23, height: 23)
                            .background(task.tint.gradient, in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                            .padding(12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 190, height: 214)
                VStack(spacing: 3) {
                    Text(task.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text(task.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
                .padding(.top, 10)
            }
            .frame(width: 190, height: 252)
            .background(.white.opacity(isSelected ? 0.88 : 0.54), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(isSelected ? task.tint.opacity(0.40) : .white.opacity(0.8), lineWidth: isSelected ? 1.4 : 1)
            }
            .shadow(color: task.tint.opacity(isSelected ? 0.12 : 0.025), radius: isSelected ? 17 : 8, x: 0, y: isSelected ? 8 : 4)
        }
        .buttonStyle(CarouselPressStyle())
        .accessibilityLabel("Preview \(task.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func taskPreview(_ task: RouteTask) -> some View {
        switch task {
        case .chat: MiniChatScreen()
        case .research: MiniResearchScreen()
        case .summary: MiniSummaryScreen()
        case .coding: MiniCodeScreen()
        case .memory: MiniMemoryScreen()
        }
    }

    private func routeRow(_ route: RouteConfiguration) -> some View {
        let selected = selectedTask == route.task
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedTask = route.task
            }
            editingTask = route.task
        } label: {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(route.task.tint.opacity(0.12))
                    .frame(width: 43, height: 43)
                    .overlay {
                        Image(systemName: route.task.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(route.task.tint)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.task.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text(route.task.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(route.provider.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text(route.provider.model)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: 115, alignment: .trailing)
                ProviderMark(provider: route.provider, size: 27)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(route.task.tint.opacity(0.055))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .matchedGeometryEffect(id: "selected-route-highlight", in: carouselNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RouteRowPressStyle())
        .accessibilityHint("Choose a provider and model for \(route.task.rawValue)")
    }

    private func providerPicker(for task: RouteTask) -> some View {
        let current = routes.first(where: { $0.task == task })?.provider
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(task.tint.opacity(0.13))
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: task.symbol).foregroundStyle(task.tint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                    Text("Choose a provider and model")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(muted)
                }
                Spacer()
            }
            .padding(.top, 8)

            ForEach(LLMProvider.choices) { provider in
                Button {
                    if let index = routes.firstIndex(where: { $0.task == task }) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            routes[index].provider = provider
                        }
                    }
                    editingTask = nil
                } label: {
                    HStack(spacing: 12) {
                        ProviderMark(provider: provider, size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(provider.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                            Text(provider.model).font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                        }
                        Spacer()
                        if current == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(task.tint)
                        }
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .background(canvas.ignoresSafeArea())
    }
}

private struct ProviderMark: View {
    let provider: LLMProvider
    var size: CGFloat = 28
    var body: some View {
        Text(provider.mark)
            .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
            .foregroundStyle(provider.tint)
            .frame(width: size, height: size)
            .background(provider.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                    .strokeBorder(provider.tint.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct CarouselPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct RouteRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Actual SwiftUI screens rendered inside ScreenMiniature

private struct MiniPhoneFrame<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41").font(.system(size: 25, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "cellularbars").font(.system(size: 20, weight: .semibold))
                Image(systemName: "wifi").font(.system(size: 19, weight: .semibold))
                Image(systemName: "battery.100percent").font(.system(size: 21, weight: .medium))
            }
            .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.28))
            .padding(.horizontal, 24)
            .frame(height: 62)
            content
            Spacer(minLength: 0)
        }
        .frame(width: 390, height: 844)
        .background(Color(red: 0.975, green: 0.969, blue: 0.990))
        .clipped()
    }
}

private struct MiniChatScreen: View {
    var body: some View {
        MiniPhoneFrame {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    Image(systemName: "chevron.left").font(.system(size: 24, weight: .semibold)).foregroundStyle(.purple)
                    Circle().fill(LinearGradient(colors: [.pink.opacity(0.75), .purple.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 49, height: 49).overlay(Image(systemName: "heart.fill").foregroundStyle(.white).font(.system(size: 21)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alex").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("online now").font(.system(size: 15, weight: .medium)).foregroundStyle(.green)
                    }
                    Spacer()
                    Image(systemName: "video").font(.system(size: 22, weight: .medium)).foregroundStyle(.purple)
                }
                .padding(.horizontal, 22).padding(.vertical, 18).background(.white)
                Rectangle().fill(.black.opacity(0.05)).frame(height: 1)
                VStack(alignment: .leading, spacing: 20) {
                    Text("TODAY  ·  9:41 AM").font(.system(size: 12, weight: .semibold)).tracking(1).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 25)
                    chatBubble("Morning! Did you sleep well?", incoming: true)
                    chatBubble("Surprisingly well ☁️", incoming: false)
                    chatBubble("I saved you a little place by the window.", incoming: true)
                    chatBubble("That sounds perfect ✨", incoming: false)
                    Spacer()
                }.padding(.horizontal, 18)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 27)).foregroundStyle(.purple)
                    Text("Message...").font(.system(size: 17)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 31)).foregroundStyle(.purple)
                }.padding(.horizontal, 17).frame(height: 58).background(.white).padding(.bottom, 18)
            }
        }
    }
    private func chatBubble(_ text: String, incoming: Bool) -> some View {
        HStack {
            if !incoming { Spacer(minLength: 48) }
            Text(text).font(.system(size: 16, weight: .medium)).foregroundStyle(incoming ? Color(red: 0.28, green: 0.25, blue: 0.35) : .white).padding(.horizontal, 17).padding(.vertical, 13).background(incoming ? Color.white : Color(red: 0.63, green: 0.53, blue: 0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if incoming { Spacer(minLength: 35) }
        }
    }
}

private struct MiniResearchScreen: View {
    var body: some View {
        MiniPhoneFrame {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("Research").font(.system(size: 30, weight: .bold, design: .rounded)); Spacer(); Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 23)).foregroundStyle(.teal) }.padding(.horizontal, 23).padding(.top, 18)
                HStack(spacing: 10) { Image(systemName: "magnifyingglass").foregroundStyle(.teal); Text("Quiet cafés in Kyoto").font(.system(size: 16, weight: .medium)); Spacer(); Image(systemName: "arrow.up.circle.fill").foregroundStyle(.teal).font(.system(size: 23)) }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 17)).padding(.horizontal, 20)
                HStack(spacing: 7) { Image(systemName: "sparkle").foregroundStyle(.teal); Text("Research summary").font(.system(size: 18, weight: .bold, design: .rounded)) }.padding(.horizontal, 22)
                Text("A few thoughtful places, away from the crowds.").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 22)
                researchCard("Weekenders Coffee", subtitle: "Minimal · riverside", symbol: "cup.and.saucer.fill", color: .teal)
                researchCard("% Arabica Higashiyama", subtitle: "Bright views · slow mornings", symbol: "sun.max.fill", color: .orange)
                researchCard("Kurasu Kyoto", subtitle: "Local roasters · calm", symbol: "leaf.fill", color: .green)
                Spacer()
            }
        }
    }
    private func researchCard(_ title: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 13) { RoundedRectangle(cornerRadius: 13).fill(color.opacity(0.12)).frame(width: 48, height: 48).overlay(Image(systemName: symbol).foregroundStyle(color).font(.system(size: 19))); VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 15, weight: .semibold)); Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20)
    }
}

private struct MiniSummaryScreen: View {
    var body: some View {
        MiniPhoneFrame {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Image(systemName: "chevron.left").foregroundStyle(.pink); Spacer(); Image(systemName: "ellipsis").foregroundStyle(.secondary) }.padding(.horizontal, 24).padding(.top, 16)
                VStack(alignment: .leading, spacing: 8) { Text("A little recap").font(.system(size: 29, weight: .bold, design: .rounded)); Text("Your conversation, thoughtfully gathered.").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary) }.padding(.horizontal, 23)
                HStack(spacing: 9) { Image(systemName: "heart.fill").foregroundStyle(.pink); Text("The important bits").font(.system(size: 17, weight: .bold, design: .rounded)) }.padding(.horizontal, 23).padding(.top, 8)
                summaryLine("You want to take more slow mornings.", number: "01")
                summaryLine("The Kyoto trip is planned for November.", number: "02")
                summaryLine("Remember the little café by the river.", number: "03")
                VStack(alignment: .leading, spacing: 9) { Text("A note to keep").font(.system(size: 15, weight: .bold)); Text("Make room for the things that make an ordinary day feel special.").font(.system(size: 15, weight: .medium)).lineSpacing(5).foregroundStyle(Color(red: 0.39, green: 0.34, blue: 0.45)) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 20)
                Spacer()
            }
        }
    }
    private func summaryLine(_ text: String, number: String) -> some View {
        HStack(alignment: .top, spacing: 12) { Text(number).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.pink).padding(.top, 2); Text(text).font(.system(size: 15, weight: .medium)).lineSpacing(4); Spacer(minLength: 0) }.padding(.horizontal, 23)
    }
}

private struct MiniCodeScreen: View {
    var body: some View {
        MiniPhoneFrame {
            VStack(alignment: .leading, spacing: 17) {
                HStack { Image(systemName: "chevron.left").foregroundStyle(.green); Text("Code helper").font(.system(size: 20, weight: .bold, design: .rounded)); Spacer(); Image(systemName: "ellipsis").foregroundStyle(.secondary) }.padding(.horizontal, 22).padding(.top, 17)
                Text("Refactor this function").font(.system(size: 25, weight: .bold, design: .rounded)).padding(.horizontal, 22)
                Text("Keep the behavior, make the intent clearer.").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 22)
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Circle().fill(.red.opacity(0.8)).frame(width: 7, height: 7); Circle().fill(.orange.opacity(0.8)).frame(width: 7, height: 7); Circle().fill(.green.opacity(0.8)).frame(width: 7, height: 7); Spacer(); Text("swift").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.55)) }
                    codeLine("func", " makeTitle", "(_ text: String) {")
                    codeLine("    let", " clean", " = text.trimming")
                    codeLine("    return", " clean", ".capitalized")
                    Text("}").font(.system(size: 13, design: .monospaced)).foregroundStyle(.white.opacity(0.82))
                }.padding(16).background(Color(red: 0.13, green: 0.15, blue: 0.20), in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 18)
                HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("Simpler · same behavior").font(.system(size: 13, weight: .semibold)) }.padding(.horizontal, 22)
                Spacer()
                HStack { Text("Ask a follow-up...").font(.system(size: 14)).foregroundStyle(.secondary); Spacer(); Image(systemName: "arrow.up.circle.fill").font(.system(size: 25)).foregroundStyle(.green) }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 17)).padding(.horizontal, 17).padding(.bottom, 18)
            }
        }
    }
    private func codeLine(_ a: String, _ b: String, _ c: String) -> some View {
        (Text(a).foregroundColor(Color(red: 0.81, green: 0.65, blue: 0.98)) + Text(b).foregroundColor(Color(red: 0.55, green: 0.85, blue: 0.73)) + Text(c).foregroundColor(.white.opacity(0.82))).font(.system(size: 12, design: .monospaced))
    }
}

private struct MiniMemoryScreen: View {
    var body: some View {
        MiniPhoneFrame {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("Memory garden").font(.system(size: 28, weight: .bold, design: .rounded)); Spacer(); Image(systemName: "sparkles").foregroundStyle(.orange).font(.system(size: 22)) }.padding(.horizontal, 22).padding(.top, 18)
                Text("Little things worth remembering").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 22)
                memoryCard("Likes quiet mornings", detail: "A slow start makes the day feel kinder.", symbol: "sunrise.fill", color: .orange)
                memoryCard("Dreams of Kyoto", detail: "Small streets, good coffee, no rush.", symbol: "leaf.fill", color: .green)
                memoryCard("A favorite song", detail: "The one playing in the car last Sunday.", symbol: "music.note", color: .purple)
                Spacer()
            }
        }
    }
    private func memoryCard(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 13) { Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(color).frame(width: 40, height: 40).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 16, weight: .bold)); Text(detail).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).lineSpacing(3) }; Spacer(minLength: 0) }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 18)
    }
}
