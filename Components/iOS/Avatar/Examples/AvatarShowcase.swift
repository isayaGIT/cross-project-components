#if canImport(SwiftUI)
import SwiftUI
import Avatar

/// Drop this file into a SwiftUI app target that depends on the Avatar package,
/// or copy the view into an app target to explore the component interactively.
struct AvatarShowcase: View {
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    section("1 · Shapes") {
                        demo("Circle", detail: "Default profile style") {
                            Avatar(image: symbol("person.fill"), width: 76, height: 76, pokeEnabled: true, vibration: 1)
                        }
                        demo("Rounded rectangle", detail: "Corner radius 16") {
                            Avatar(image: symbol("person.fill"), width: 76, height: 76,
                                   shape: .roundedRectangle(cornerRadius: 16), pokeEnabled: true, vibration: 1)
                        }
                        demo("Square", detail: "No corner clipping") {
                            Avatar(image: symbol("person.fill"), width: 76, height: 76, shape: .square, pokeEnabled: true, vibration: 1)
                        }
                    }

                    section("2 · Sizes and proportions") {
                        demo("Tiny · 20", detail: "Compact list row") {
                            Avatar(image: symbol("person.crop.circle.fill"), width: 20, height: 20, pokeEnabled: true, vibration: 1)
                        }
                        demo("Small · 32", detail: "Dense UI") {
                            Avatar(image: symbol("person.fill"), width: 32, height: 32, pokeEnabled: true, vibration: 1)
                        }
                        demo("Standard · 48", detail: "Chat message") {
                            Avatar(image: symbol("person.fill"), width: 48, height: 48, pokeEnabled: true, vibration: 1)
                        }
                        demo("Large · 96", detail: "Profile header") {
                            Avatar(image: symbol("person.fill"), width: 96, height: 96, pokeEnabled: true, vibration: 1)
                        }
                        demo("Wide · 110 × 64", detail: "Ellipse crop") {
                            Avatar(image: symbol("person.fill"), width: 110, height: 64, pokeEnabled: true, vibration: 1)
                        }
                        demo("Tall · 64 × 110", detail: "Portrait frame") {
                            Avatar(image: symbol("person.fill"), width: 64, height: 110, pokeEnabled: true, vibration: 1)
                        }
                    }

                    section("3 · Image scaling") {
                        demo("Fill", detail: "Covers the frame; may crop") {
                            Avatar(image: landscape, width: 110, height: 72, shape: .roundedRectangle(cornerRadius: 12), scaling: .fill, pokeEnabled: true, vibration: 1)
                        }
                        demo("Fit", detail: "Whole image; may leave space") {
                            Avatar(image: landscape, width: 110, height: 72, shape: .roundedRectangle(cornerRadius: 12), scaling: .fit, pokeEnabled: true, vibration: 1)
                        }
                        demo("Portrait · fill", detail: "Portrait symbol") {
                            Avatar(image: symbol("person.crop.rectangle.fill"), width: 72, height: 100, shape: .roundedRectangle(cornerRadius: 12), scaling: .fill, pokeEnabled: true, vibration: 1)
                        }
                        demo("Portrait · fit", detail: "Preserve full symbol") {
                            Avatar(image: symbol("person.crop.rectangle.fill"), width: 72, height: 100, shape: .roundedRectangle(cornerRadius: 12), scaling: .fit, pokeEnabled: true, vibration: 1)
                        }
                    }

                    section("4 · Different image content") {
                        demo("Person", detail: "Profile glyph") {
                            Avatar(image: symbol("person.fill"), width: 72, height: 72, pokeEnabled: true, vibration: 1)
                        }
                        demo("Group", detail: "Team / community") {
                            Avatar(image: symbol("person.3.fill"), width: 72, height: 72, pokeEnabled: true, vibration: 1)
                        }
                        demo("Cat", detail: "Pet profile") {
                            Avatar(image: symbol("cat.fill"), width: 72, height: 72, pokeEnabled: true, vibration: 1)
                        }
                        demo("Landscape", detail: "Photo-like artwork") {
                            Avatar(image: landscape, width: 72, height: 72, pokeEnabled: true, vibration: 1)
                        }
                        demo("Initials overlay", detail: "Overlay belongs to caller") {
                            ZStack {
                                Circle().fill(.purple.gradient)
                                Avatar(image: nil, width: 72, height: 72, pokeEnabled: true, vibration: 1)
                                Text("AK").font(.title2.bold()).foregroundStyle(.white)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                        }
                        demo("Emoji overlay", detail: "Caller-defined visual") {
                            ZStack {
                                Circle().fill(.orange.gradient)
                                Avatar(image: nil, width: 72, height: 72, pokeEnabled: true, vibration: 1)
                                Text("🦊").font(.system(size: 38))
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                        }
                    }

                    section("5 · Empty and placeholder states") {
                        demo("Default silhouette", detail: "Vector-drawn, themeable colors") {
                            Avatar(image: nil, width: 72, height: 72, pokeEnabled: true, vibration: 1)
                        }
                        demo("Custom palette · indigo", detail: "Background + silhouette colors") {
                            Avatar(image: nil, width: 72, height: 72, placeholderStyle: .init(
                                background: Color.indigo.opacity(0.22), foreground: Color.indigo
                            ), pokeEnabled: true, vibration: 1)
                        }
                        demo("Custom palette · mint", detail: "Another theme example") {
                            Avatar(image: nil, width: 72, height: 72, placeholderStyle: .init(
                                background: Color.mint.opacity(0.3), foreground: Color.teal
                            ), pokeEnabled: true, vibration: 1)
                        }
                        demo("Empty · rounded", detail: "Rounded placeholder") {
                            Avatar(image: nil, width: 72, height: 72, shape: .roundedRectangle(cornerRadius: 18), pokeEnabled: true, vibration: 1)
                        }
                        demo("Custom placeholder", detail: "Pass an SF Symbol") {
                            Avatar(image: nil, width: 72, height: 72, placeholder: symbol("person.crop.circle.badge.questionmark"), pokeEnabled: true, vibration: 1)
                        }
                        demo("Custom placeholder · square", detail: "Square + custom symbol") {
                            Avatar(image: nil, width: 72, height: 72, shape: .square, placeholder: symbol("photo.fill"), pokeEnabled: true, vibration: 1)
                        }
                    }

                    section("6 · WeChat-style poke") {
                        demo("Poke enabled · circle", detail: "Double-tap the avatar to wobble") {
                            Avatar(image: symbol("person.fill"), width: 76, height: 76,
                                   pokeEnabled: true, vibration: 1)
                        }
                        demo("Poke enabled · rounded", detail: "Double-tap the avatar to wobble") {
                            Avatar(image: symbol("person.fill"), width: 76, height: 76,
                                   shape: .roundedRectangle(cornerRadius: 18), pokeEnabled: true, vibration: 1)
                        }
                        demo("Empty avatar · poke", detail: "Works with the vector placeholder too") {
                            Avatar(image: nil, width: 76, height: 76,
                                   placeholderStyle: .init(background: Color.indigo.opacity(0.22), foreground: .indigo),
                                   pokeEnabled: true, vibration: 1)
                        }
                    }

                    section("7 · Edge cases") {
                        demo("Very wide", detail: "160 × 44") {
                            Avatar(image: landscape, width: 160, height: 44, shape: .roundedRectangle(cornerRadius: 10), pokeEnabled: true, vibration: 1)
                        }
                        demo("Very tall", detail: "44 × 120") {
                            Avatar(image: landscape, width: 44, height: 120, shape: .roundedRectangle(cornerRadius: 10), pokeEnabled: true, vibration: 1)
                        }
                        demo("Zero width", detail: "Should render no width") {
                            Avatar(image: symbol("person.fill"), width: 0, height: 48, pokeEnabled: true, vibration: 1)
                        }
                        demo("Zero height", detail: "Should render no height") {
                            Avatar(image: symbol("person.fill"), width: 48, height: 0, pokeEnabled: true, vibration: 1)
                        }
                    }
                }
                .padding(18)
            }
            .navigationTitle("Avatar Showcase")
        }
    }

    private var landscape: Image {
        Image(systemName: "mountain.2.fill")
    }

    private func symbol(_ name: String) -> Image {
        Image(systemName: name)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        } header: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func demo<Content: View>(
        _ title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.08))
                content()
                    .foregroundStyle(.primary)
            }
            .frame(height: 132)
            .frame(maxWidth: .infinity)

            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Avatar gallery") {
    AvatarShowcase()
}
#endif
