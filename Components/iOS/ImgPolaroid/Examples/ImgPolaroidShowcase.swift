import SwiftUI
import ImgPolaroid

public struct ImgPolaroidShowcase: View {
    @State private var offset = CGSize.zero
    @State private var selected = false
    @State private var rotation = -5.0
    @State private var status = "Hold to lift · drag corners to rotate"

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.88, blue: 0.81).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Little Moments")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.25, green: 0.22, blue: 0.18))
                Text(status).font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Polaroid(
                    image: Image(systemName: "sun.max.fill"),
                    caption: "A sunny day",
                    width: 190,
                    rotation: $rotation,
                    position: $offset,
                    isRaised: $selected,
                    onTap: { status = "Photo tapped" },
                    onRotationChange: { angle in status = "Rotation callback · \(Int(angle.rounded()))°" }
                )
                Spacer(minLength: 12)
                Text("Tap to select · drag to move")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 24)
        }
    }
}
