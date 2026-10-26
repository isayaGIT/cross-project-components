import SwiftUI

@main
struct CardGeneralDemoApp: App {
    var body: some Scene { WindowGroup { CardGeneralPlayground() } }
}

private struct CardGeneralPlayground: View {
    @State private var selectedPalette: CardGeneralPalette = .pearl
    @State private var darkCanvas = false
    @State private var useCircle = false
    @State private var showContent = false
    private var canvas: Color { darkCanvas ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color(red: 0.91, green: 0.92, blue: 0.94) }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("CardGeneral · 原版材质层").font(.headline)
                Spacer()
                Toggle("深色画布", isOn: $darkCanvas).labelsHidden()
            }
            Toggle("显示中心 Content", isOn: $showContent)
            Picker("形状", selection: $useCircle) {
                Text("圆角矩形").tag(false)
                Text("圆形").tag(true)
            }.pickerStyle(.segmented)
            Picker("材质", selection: $selectedPalette) {
                Text("Obsidian").tag(CardGeneralPalette.graphite)
                Text("Pearl").tag(CardGeneralPalette.pearl)
                Text("Sapphire").tag(CardGeneralPalette.sapphire)
                Text("Amethyst").tag(CardGeneralPalette.amethyst)
                Text("Rose").tag(CardGeneralPalette.rose)
                Text("Emerald").tag(CardGeneralPalette.emerald)
            }.pickerStyle(.segmented)
            Spacer(minLength: 12)
            demoCard
                .frame(width: useCircle ? 280 : 320, height: 320)
                .padding(.horizontal, 28)
            Spacer(minLength: 12)
            Text("中心内容应完整透出；只保留沿形状的反射边缘与投影")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .background(canvas.ignoresSafeArea())
        .preferredColorScheme(darkCanvas ? .dark : .light)
    }

    @ViewBuilder
    private var demoCard: some View {
        if useCircle {
            CardGeneral(shape: Circle(), thickness: 7, palette: selectedPalette) { cardContent }
        } else {
            CardGeneral(shape: RoundedRectangle(cornerRadius: 24, style: .continuous), thickness: 7, palette: selectedPalette) { cardContent }
        }
    }

    private var cardContent: some View {
        Group {
            if showContent { centerArtwork } else { Color.clear }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var centerArtwork: some View {
        ZStack {
            LinearGradient(colors: [.pink, .orange, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 34, weight: .medium))
                Text("透明中心").font(.system(size: 22, weight: .bold))
                Text("背景 / Content 可见").font(.system(size: 12, weight: .medium))
            }.foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
