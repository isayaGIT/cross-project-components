import CrossProjectComponentsIOS
import SwiftUI

@main
struct MessageBubbleDemoApp: App {
  var body: some Scene {
    WindowGroup {
      MessageBubbleDemoView()
    }
  }
}

private struct MessageBubbleDemoView: View {
  @State private var corner: CornerSide = .right
  @State private var radius = 20.0
  @State private var useGradient = true
  @State private var showGallery = true
  @State private var useTail = false
  @State private var showTimestamp = true
  @State private var borderStyle: BorderStyle = .dashed
  @State private var messageFontSize = 16.0
  @State private var messageLineSpacing = 3.0
  @State private var lastAction = "No action yet"

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          introduction
          controls
          animatedNinePatchPreview
          conversation
          if showGallery { geometryGallery }
        }
        .padding(20)
        .frame(maxWidth: 620, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle("MessageBubble")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .font(.title2)
          .foregroundStyle(.tint)
        Text("Native SwiftUI component")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text("One component. Two silhouettes.")
        .font(.system(size: 29, weight: .bold, design: .rounded))
        .tracking(-0.7)
      Text("Switch between a clean square corner and a continuous rounded tail. Optional timestamps sit outside the bubble.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("Bottom corner", systemImage: "arrow.turn.down.right")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Picker("Corner", selection: $corner) {
          ForEach(CornerSide.allCases) { side in
            Text(side.title).tag(side)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 150)
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Corner radius")
          Spacer()
          Text("\(Int(radius)) pt")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Slider(value: $radius, in: 8...32, step: 1)
          .tint(.accentColor)
      }

      Picker("Bubble style", selection: $useTail) {
        Text("Tail-less").tag(false)
        Text("Rounded tail").tag(true)
      }
      .pickerStyle(.segmented)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Message font size")
          Spacer()
          Text("\(Int(messageFontSize)) pt").monospacedDigit().foregroundStyle(.secondary)
        }
        Slider(value: $messageFontSize, in: 12...24, step: 1)
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Line spacing")
          Spacer()
          Text("\(Int(messageLineSpacing)) pt").monospacedDigit().foregroundStyle(.secondary)
        }
        Slider(value: $messageLineSpacing, in: 0...12, step: 1)
      }

      Toggle(isOn: $showTimestamp) {
        Label("Show external timestamps", systemImage: "clock")
      }
      .font(.subheadline)

      VStack(alignment: .leading, spacing: 8) {
        Label("Bubble border", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
          .font(.subheadline.weight(.semibold))
        Picker("Bubble border", selection: $borderStyle) {
          ForEach(BorderStyle.allCases) { option in
            Text(option.title).tag(option)
          }
        }
        .pickerStyle(.segmented)
        Text("Dashed borders use LineDashed. Dash length, spacing, thickness and fill are configurable.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Toggle(isOn: $useGradient) {
        Label("Gradient fill", systemImage: "paintpalette")
      }
      .font(.subheadline)

      Toggle(isOn: $showGallery) {
        Label("Show all corner positions", systemImage: "square.on.circle")
      }
      .font(.subheadline)
    }
    .padding(16)
    .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    }
  }

  private var animatedNinePatchPreview: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("ANIMATED NINE-PATCH", detail: "12 original repository PNG frames · fixed corners · stretchable center")
      HStack(alignment: .bottom, spacing: 10) {
        avatar("M", color: .purple)
        VStack(alignment: .leading, spacing: 4) {
          Text("Morgan · animated skin")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 5) {
            Text("The bubble itself is animated.")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.black)
            Text("This is a longer multi-line message to demonstrate that the bubble grows taller automatically as the text wraps onto additional lines. The frame animation stays behind the full content.")
              .font(.system(size: 13))
              .foregroundStyle(.black)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.horizontal, 31)
          .padding(.vertical, 22)
          .frame(width: 285, alignment: .leading)
          .background {
            NinePatchFrameAnimation(
              frameNames: (1...12).map { String(format: "OriginalBubbleFrame%02d", $0) },
              sourceSize: CGSize(width: 128, height: 112),
              // Preserve the source frame's corners; let the central band stretch in both axes.
              stretchInsets: EdgeInsets(top: 52, leading: 60, bottom: 59, trailing: 67),
              duration: 1.0,
              repeatCount: 0
            )
          }
          .accessibilityElement(children: .combine)
        }
        Spacer(minLength: 0)
      }
      HStack {
        Spacer(minLength: 44)
        Text("Mirrored outgoing bubble — this one also grows to fit a longer multi-line message. ✨")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.black)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 31)
          .padding(.vertical, 22)
          .frame(width: 250, alignment: .leading)
          .background {
            NinePatchFrameAnimation(
              frameNames: (1...12).map { String(format: "OriginalBubbleFrame%02d", $0) },
              sourceSize: CGSize(width: 128, height: 112),
              stretchInsets: EdgeInsets(top: 52, leading: 60, bottom: 59, trailing: 67),
              duration: 0.72,
              repeatCount: 0,
              horizontallyMirrored: true
            )
          }
      }
    }
    .padding(16)
    .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(.quaternary, lineWidth: 1)
    }
  }

  private var conversation: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("LIVE PREVIEW", detail: "Changes apply instantly")
      Text("Long-press a message, swipe to an action, then release · Last action: \(lastAction)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("messageBubbleActionStatus")

      HStack(alignment: .bottom, spacing: 10) {
        avatar("M", color: .purple)
        VStack(alignment: .leading, spacing: 4) {
          Text("Morgan")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          MessageBubble(
            cornerRadius: radius,
            sharpCorner: .bottomLeading,
            style: useTail ? .roundedTail : .tailLess,
            fill: Color(uiColor: .secondarySystemGroupedBackground),
            border: currentBorder,
            padding: EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14),
            timestamp: showTimestamp ? "16:08" : nil,
            metadataAlignment: .leading,
            font: .system(size: messageFontSize),
            lineSpacing: messageLineSpacing
          ) {
            Text(
              "Hey! This is the incoming bubble. Notice the bottom-left corner is perfectly square."
            )
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
          }
          .messageBubbleActions(items: [
            .init(symbol: "doc.on.doc", label: "Copy") { lastAction = "Copy fired" },
            .init(symbol: "arrowshape.turn.up.left", label: "Reply") { lastAction = "Reply fired" },
            .init(symbol: "heart", label: "React") { lastAction = "React fired" }
          ], tint: .pink)
        }
        Spacer(minLength: 16)
      }

      HStack(alignment: .bottom, spacing: 10) {
        Spacer(minLength: 40)
        VStack(alignment: .trailing, spacing: 4) {
          Text("You · 9:41 AM")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
          MessageBubble(
            cornerRadius: radius,
            sharpCorner: corner.sharpCorner,
            style: useTail ? .roundedTail : .tailLess,
            fill: bubbleFill,
            border: currentBorder,
            padding: EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14),
            timestamp: showTimestamp ? "16:09" : nil,
            metadataAlignment: .trailing,
            font: .system(size: messageFontSize),
            lineSpacing: messageLineSpacing
          ) {
            Text("And this is the outgoing message. Drag the controls above to explore the shape.")
                .foregroundStyle(.white)
              .fixedSize(horizontal: false, vertical: true)
          }
          .shadow(color: .blue.opacity(0.16), radius: 9, y: 3)
        }
        avatar("Z", color: .blue)
      }

      HStack(alignment: .bottom, spacing: 10) {
        avatar("M", color: .purple)
        MessageBubble(
          cornerRadius: radius,
          sharpCorner: .bottomLeading,
          fill: Color(uiColor: .secondarySystemGroupedBackground),
          border: currentBorder
        ) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Long content stays content-driven")
              .font(.system(size: 15, weight: .semibold))
            Text(
              "A reusable bubble should handle multiple lines naturally without knowing anything about messages, senders, or chat state."
            )
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
          }
          .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 26)
      }
    }
  }

  private var geometryGallery: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("SHAPE GALLERY", detail: "All four supported corner positions")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(CornerPosition.allCases) { position in
          galleryItem(position)
        }
      }
    }
  }

  private func galleryItem(_ position: CornerPosition) -> some View {
    let isSelected = position == corner.position
    let fill: AnyShapeStyle =
      isSelected
      ? bubbleFill
      : AnyShapeStyle(Color(uiColor: .tertiarySystemFill))
    let outline = isSelected ? Color.blue.opacity(0.45) : Color.secondary.opacity(0.12)

    return VStack(alignment: .leading, spacing: 10) {
      MessageBubbleShape(cornerRadius: radius, sharpCorner: position.sharpCorner)
        .fill(fill)
        .frame(height: 74)
        .overlay {
          MessageBubbleShape(cornerRadius: radius, sharpCorner: position.sharpCorner)
            .stroke(outline, lineWidth: 1)
        }
      HStack {
        Text(position.title)
          .font(.subheadline.weight(.medium))
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.blue)
        }
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contentShape(Rectangle())
    .onTapGesture {
      if let side = position.side { corner = side }
    }
  }

  private var currentBorder: MessageBubbleBorder {
    switch borderStyle {
    case .none:
      .none
    case .solid:
      .solid(color: .secondary.opacity(0.35), lineWidth: 1)
    case .dashed:
      .dashed(
        configuration: .init(lineWidth: 2, dashLength: 8, dashSpacing: 4, cornerRadius: 1),
        fill: .color(.purple)
      )
    }
  }

  private var bubbleFill: AnyShapeStyle {
    if useGradient {
      AnyShapeStyle(
        LinearGradient(
          colors: [
            Color(red: 0.16, green: 0.48, blue: 0.96), Color(red: 0.29, green: 0.36, blue: 0.91),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
    } else {
      AnyShapeStyle(Color.accentColor)
    }
  }

  private func avatar(_ letter: String, color: Color) -> some View {
    Image("OriginalCatAvatar")
      .resizable()
      .scaledToFill()
      .frame(width: 34, height: 34)
      .clipShape(Circle())
      .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1))
      .accessibilityLabel("Original repository cat avatar")
  }

  private func sectionHeader(_ title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption.weight(.bold))
        .tracking(1.1)
        .foregroundStyle(.secondary)
      Text(detail)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }
}

private enum CornerSide: String, CaseIterable, Identifiable {
  case left
  case right

  var id: String { rawValue }
  var title: String { self == .left ? "Left" : "Right" }
  var sharpCorner: MessageBubbleShape.SharpCorner {
    self == .left ? .bottomLeading : .bottomTrailing
  }
  var position: CornerPosition { self == .left ? .bottomLeading : .bottomTrailing }
}

private enum CornerPosition: String, CaseIterable, Identifiable {
  case topLeading
  case topTrailing
  case bottomLeading
  case bottomTrailing

  var id: String { rawValue }
  var title: String {
    switch self {
    case .topLeading: "Top left"
    case .topTrailing: "Top right"
    case .bottomLeading: "Bottom left"
    case .bottomTrailing: "Bottom right"
    }
  }

  var sharpCorner: MessageBubbleShape.SharpCorner {
    switch self {
    case .topLeading: .topLeading
    case .topTrailing: .topTrailing
    case .bottomLeading: .bottomLeading
    case .bottomTrailing: .bottomTrailing
    }
  }

  var side: CornerSide? {
    switch self {
    case .bottomLeading: .left
    case .bottomTrailing: .right
    default: nil
    }
  }
}

private enum BorderStyle: String, CaseIterable, Identifiable {
  case none
  case solid
  case dashed

  var id: String { rawValue }
  var title: String {
    switch self {
    case .none: "None"
    case .solid: "Solid"
    case .dashed: "Dashed"
    }
  }
}

#Preview("MessageBubble Playground") {
  MessageBubbleDemoView()
}
