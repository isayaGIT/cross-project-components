import SwiftUI

private struct RouteTask: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let provider: String
    let model: String
    var preview: PreviewScene
}

private enum PreviewScene { case forest, castle, moon, code, sunset }

private enum DemoAlert: Identifiable {
    case settings, allRoutesConfigured
    var id: Int { self == .settings ? 0 : 1 }
}

private struct Provider: Identifiable, Equatable {
    let id: String
    let model: String
    let mark: String
    let tint: Color
}

struct LLMRoutesDemoView: View {
    private let ink = Color(red: 0.19, green: 0.22, blue: 0.36)
    private let muted = Color(red: 0.48, green: 0.52, blue: 0.63)
    private let canvas = Color(red: 0.955, green: 0.957, blue: 0.985)
    private let line = Color(red: 0.89, green: 0.90, blue: 0.95)
    private let providers: [Provider] = [
        .init(id: "OpenAI", model: "GPT-4o", mark: "✳", tint: Color(red: 0.19, green: 0.65, blue: 0.62)),
        .init(id: "Anthropic", model: "Claude 3.5 Sonnet", mark: "AI", tint: Color(red: 0.78, green: 0.55, blue: 0.39)),
        .init(id: "Google", model: "Gemini 1.5 Pro", mark: "G", tint: Color(red: 0.31, green: 0.54, blue: 0.88)),
        .init(id: "Midjourney", model: "Midjourney v6", mark: "◢", tint: Color(red: 0.42, green: 0.47, blue: 0.58))
    ]
    private let tasks: [RouteTask] = [
        .init(id: "general", title: "General Chat", subtitle: "Casual conversation, daily life", symbol: "bubble.left.and.bubble.right.fill", tint: Color(red: 0.59, green: 0.48, blue: 0.92), provider: "OpenAI", model: "GPT-4o", preview: .castle),
        .init(id: "research", title: "Research", subtitle: "Web search, knowledge, info", symbol: "magnifyingglass", tint: Color(red: 0.39, green: 0.63, blue: 0.94), provider: "Anthropic", model: "Claude 3.5 Sonnet", preview: .moon),
        .init(id: "coding", title: "Code Assistant", subtitle: "Programming, debugging", symbol: "chevron.left.forwardslash.chevron.right", tint: Color(red: 0.62, green: 0.43, blue: 0.94), provider: "Google", model: "Gemini 1.5 Pro", preview: .code),
        .init(id: "writing", title: "Creative Writing", subtitle: "Story, copywriting, idea", symbol: "pencil.and.outline", tint: Color(red: 0.94, green: 0.40, blue: 0.64), provider: "Anthropic", model: "Claude 3.5 Sonnet", preview: .forest),
        .init(id: "image", title: "Image Generation", subtitle: "Illustration, design, image", symbol: "photo.artframe", tint: Color(red: 0.97, green: 0.65, blue: 0.29), provider: "Midjourney", model: "Midjourney v6", preview: .sunset),
        .init(id: "character", title: "Character Analysis", subtitle: "Personality, emotion, behavior", symbol: "person.crop.circle.fill", tint: Color(red: 0.28, green: 0.74, blue: 0.70), provider: "OpenAI", model: "GPT-4o", preview: .forest),
        .init(id: "document", title: "Document Processing", subtitle: "Long text, summarization", symbol: "doc.text.fill", tint: Color(red: 0.36, green: 0.61, blue: 0.96), provider: "Google", model: "Gemini 1.5 Pro", preview: .code),
        .init(id: "tools", title: "System & Tools", subtitle: "API calls, external tools", symbol: "gearshape.fill", tint: Color(red: 0.55, green: 0.59, blue: 0.69), provider: "OpenAI", model: "GPT-4o", preview: .moon)
    ]

    @State private var selectedPreview = 1
    @State private var editingTask: RouteTask?
    @State private var assignments: [String: String] = [:]
    @State private var activeAlert: DemoAlert?

    private func provider(for task: RouteTask) -> Provider {
        let name = assignments[task.id] ?? task.provider
        return providers.first(where: { $0.id == name }) ?? providers[0]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 5)
                        .padding(.bottom, 16)

                    carousel
                        .frame(height: 192)
                        .padding(.top, 8)
                        .offset(y: -10)
                        .padding(.bottom, 12)

                    routesPanel
                        .padding(.horizontal, 20)

                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .preferredColorScheme(.light)
        .sheet(item: $editingTask) { task in
            providerPicker(task)
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .settings:
                return Alert(title: Text("Route settings"), message: Text("Each task can use its own provider and model."), primaryButton: .destructive(Text("Reset provider assignments")) { assignments.removeAll() }, secondaryButton: .cancel())
            case .allRoutesConfigured:
                return Alert(title: Text("All available routes are configured"), message: Text("This demo includes all eight task routes from the reference."), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.975, green: 0.974, blue: 0.995), Color(red: 0.929, green: 0.947, blue: 0.982)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(red: 0.87, green: 0.82, blue: 1).opacity(0.28)).frame(width: 280).blur(radius: 55).offset(x: 175, y: -285)
            Circle().fill(Color(red: 0.94, green: 0.80, blue: 0.91).opacity(0.20)).frame(width: 250).blur(radius: 65).offset(x: -170, y: 20)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LLM Routes")
                    .font(.system(size: 21.5, weight: .medium, design: .serif))
                    .tracking(-0.65)
                    .foregroundStyle(ink)
                Text("Configure which LLM providers and models handle each task.")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 2)
            Button { activeAlert = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.86), in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                    .shadow(color: ink.opacity(0.08), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Route settings")
        }
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let cardWidth = min(194, proxy.size.width * 0.49)
            ScrollViewReader { reader in
                ZStack(alignment: .bottom) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 11) {
                            ForEach(Array([3, 0, 1, 2, 4].enumerated()), id: \.offset) { position, taskIndex in
                                let task = tasks[taskIndex]
                                sceneCard(task, width: cardWidth, selected: selectedPreview == position)
                                    .id(position)
                                    .onTapGesture { selectPreview(position, reader: reader) }
                            }
                        }
                        .padding(.horizontal, max(10, (proxy.size.width - cardWidth) / 2))
                        .padding(.top, 2)
                        .padding(.bottom, 23)
                    }
                    .contentMargins(.zero, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .overlay(alignment: .leading) {
                        Button { selectPreview(max(0, selectedPreview - 1), reader: reader) } label: {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(red: 0.50, green: 0.48, blue: 0.75)).frame(width: 29, height: 29).background(.white.opacity(0.94), in: Circle()).shadow(color: ink.opacity(0.12), radius: 6, y: 2)
                        }.buttonStyle(.plain).padding(.leading, 12).offset(y: -8)
                    }
                    .overlay(alignment: .trailing) {
                        Button { selectPreview(min(4, selectedPreview + 1), reader: reader) } label: {
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(red: 0.50, green: 0.48, blue: 0.75)).frame(width: 29, height: 29).background(.white.opacity(0.94), in: Circle()).shadow(color: ink.opacity(0.12), radius: 6, y: 2)
                        }.buttonStyle(.plain).padding(.trailing, 12).offset(y: -8)
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<5) { i in
                            Capsule().fill(i == selectedPreview ? Color(red: 0.60, green: 0.49, blue: 0.91) : Color(red: 0.75, green: 0.76, blue: 0.85).opacity(0.8)).frame(width: i == selectedPreview ? 7 : 5, height: 5)
                        }
                    }
                    .padding(.bottom, 7)
                }
                .onAppear { reader.scrollTo(selectedPreview, anchor: .center) }
            }
        }
    }

    private func selectPreview(_ index: Int, reader: ScrollViewProxy) {
        let safeIndex = min(4, max(0, index))
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            selectedPreview = safeIndex
            reader.scrollTo(safeIndex, anchor: .center)
        }
    }

    private func sceneCard(_ task: RouteTask, width: CGFloat, selected: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                sceneArt(task.preview)
                    .frame(width: width, height: 103)
                    .clipped()
                LinearGradient(colors: [.clear, Color(red: 0.18, green: 0.20, blue: 0.35).opacity(0.23)], startPoint: .center, endPoint: .bottom)
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(ink).lineLimit(1)
                    Text(task.subtitle).font(.system(size: 7.5, weight: .medium)).foregroundStyle(muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(muted)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(.white.opacity(0.88))
        }
        .frame(width: width)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white.opacity(selected ? 0.95 : 0.68), lineWidth: selected ? 1.5 : 0.8))
        .shadow(color: Color(red: 0.42, green: 0.38, blue: 0.64).opacity(selected ? 0.19 : 0.09), radius: selected ? 12 : 7, x: 0, y: selected ? 5 : 3)
        .scaleEffect(selected ? 1 : 0.96)
    }

    @ViewBuilder private func sceneArt(_ scene: PreviewScene) -> some View {
        switch scene {
        case .castle:
            Image("route-scene-chat").resizable().scaledToFill()
        case .moon:
            Image("route-scene-research").resizable().scaledToFill()
        case .forest:
            ZStack {
                LinearGradient(colors: [Color(red: 0.66, green: 0.79, blue: 0.93), Color(red: 0.87, green: 0.79, blue: 0.92), Color(red: 0.96, green: 0.82, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.white.opacity(0.55)).frame(width: 36).blur(radius: 1).offset(x: 48, y: -20)
                ForEach(0..<8) { i in
                    Ellipse().fill([Color(red: 0.35, green: 0.57, blue: 0.59), Color(red: 0.49, green: 0.68, blue: 0.65), Color(red: 0.59, green: 0.65, blue: 0.78)][i % 3]).frame(width: 46, height: 72).offset(x: CGFloat(i * 26 - 90), y: 38)
                }
            }
        case .code:
            ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.20, blue: 0.42), Color(red: 0.36, green: 0.39, blue: 0.69), Color(red: 0.79, green: 0.63, blue: 0.83)], startPoint: .top, endPoint: .bottom)
                ForEach(0..<18) { i in
                    Circle().fill(.white.opacity(i.isMultiple(of: 3) ? 0.8 : 0.38)).frame(width: i.isMultiple(of: 4) ? 2.5 : 1.5).offset(x: CGFloat((i * 37) % 190 - 90), y: CGFloat((i * 19) % 80 - 35))
                }
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.8))
            }
        case .sunset:
            ZStack {
                LinearGradient(colors: [Color(red: 0.98, green: 0.72, blue: 0.78), Color(red: 0.99, green: 0.84, blue: 0.70), Color(red: 0.55, green: 0.62, blue: 0.85)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.91, blue: 0.73)).frame(width: 38).offset(x: 48, y: -16)
                Image(systemName: "sparkles").font(.system(size: 35, weight: .ultraLight)).foregroundStyle(.white.opacity(0.8)).offset(x: -35, y: 4)
            }
        }
    }

    private var routesPanel: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Task Routes").font(.system(size: 15, weight: .medium, design: .serif)).foregroundStyle(ink)
                Text("8 tasks").font(.system(size: 8, weight: .medium)).foregroundStyle(muted)
                Spacer()
                Button { activeAlert = .allRoutesConfigured } label: {
                    HStack(spacing: 4) { Image(systemName: "plus").font(.system(size: 8, weight: .semibold)); Text("Add Route").font(.system(size: 9, weight: .semibold)) }
                        .foregroundStyle(Color(red: 0.52, green: 0.43, blue: 0.87))
                        .padding(.horizontal, 10).frame(height: 25)
                        .background(Color(red: 0.91, green: 0.89, blue: 1).opacity(0.60), in: Capsule())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 8)

            HStack {
                Text("Task")
                Spacer()
                Text("LLM Provider & Model").frame(width: 145, alignment: .leading)
            }
            .font(.system(size: 7.5, weight: .medium))
            .foregroundStyle(muted)
            .padding(.horizontal, 14).padding(.bottom, 5)

            Rectangle().fill(line.opacity(0.65)).frame(height: 0.6).padding(.horizontal, 12)

            ForEach(tasks) { task in
                Button { editingTask = task } label: {
                    routeRow(task)
                }
                .buttonStyle(RouteTapStyle())
                if task.id != tasks.last?.id {
                    Rectangle().fill(line.opacity(0.42)).frame(height: 0.5).padding(.leading, 49).padding(.trailing, 11)
                }
            }
        }
        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.86), lineWidth: 1))
        .shadow(color: Color(red: 0.43, green: 0.41, blue: 0.63).opacity(0.045), radius: 15, x: 0, y: 4)
    }

    private func routeRow(_ task: RouteTask) -> some View {
        let assigned = provider(for: task)
        return HStack(spacing: 8) {
            Circle()
                .fill(task.tint.gradient.opacity(0.94))
                .frame(width: 29, height: 29)
                .overlay(Image(systemName: task.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: task.tint.opacity(0.18), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                Text(task.subtitle).font(.system(size: 7, weight: .regular)).foregroundStyle(muted).lineLimit(1)
            }
            Spacer(minLength: 3)
            HStack(spacing: 6) {
                providerMark(assigned, size: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(assigned.id).font(.system(size: 8.5, weight: .medium)).foregroundStyle(ink).lineLimit(1)
                    Text(assigned.model).font(.system(size: 7, weight: .regular)).foregroundStyle(muted).lineLimit(1)
                }
                .frame(width: 89, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 7, weight: .semibold)).foregroundStyle(Color(red: 0.65, green: 0.68, blue: 0.77))
            }
            .frame(width: 139, alignment: .leading)
        }
        .padding(.horizontal, 11).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func providerMark(_ provider: Provider, size: CGFloat) -> some View {
        Text(provider.mark)
            .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
            .foregroundStyle(provider.tint)
            .frame(width: size, height: size)
            .background(.white.opacity(0.9), in: Circle())
            .overlay(Circle().strokeBorder(provider.tint.opacity(0.2), lineWidth: 0.7))
    }

    private func providerPicker(_ task: RouteTask) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 12).fill(task.tint.opacity(0.13)).frame(width: 42, height: 42).overlay(Image(systemName: task.symbol).foregroundStyle(task.tint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(ink)
                    Text("Choose a provider and model").font(.system(size: 12, weight: .medium)).foregroundStyle(muted)
                }
                Spacer()
            }.padding(.top, 6)
            ForEach(providers) { option in
                Button {
                    assignments[task.id] = option.id
                    editingTask = nil
                } label: {
                    HStack(spacing: 12) {
                        providerMark(option, size: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.id).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                            Text(option.model).font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                        }
                        Spacer()
                        if provider(for: task) == option { Image(systemName: "checkmark.circle.fill").font(.system(size: 19)).foregroundStyle(task.tint) }
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .background(canvas.ignoresSafeArea())
    }
}

private struct RouteTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
