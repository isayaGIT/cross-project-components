#if canImport(SwiftUI) && canImport(UIKit) && canImport(MetalKit)
import SwiftUI
import UIKit
import MetalKit

/// Native SwiftUI/Metal port of the supplied OpenShaders @isaya WebGL2 shader.
/// The upstream repository currently contains the project README and license, not the platform source.
public struct OpenShadersView: UIViewRepresentable {
    public enum Theme: Equatable {
        case dark
        case light
        case system
    }

    public struct Background: Equatable {
        public var dark: Color
        public var light: Color

        public init(dark: Color = Color(red: 9 / 255, green: 9 / 255, blue: 9 / 255),
                    light: Color = .white) {
            self.dark = dark
            self.light = light
        }

        public static let `default` = Background()
    }

    public var theme: Theme
    public var background: Background

    public init(theme: Theme = .system, background: Background = .default) {
        self.theme = theme
        self.background = background
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0.035, green: 0.035, blue: 0.035, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        // Let MTKView track its real laid-out bounds. The first SwiftUI update can
        // happen while bounds are still zero-sized; freezing drawableSize here
        // leaves the shader rendering into a tiny drawable until the view is
        // recreated (which is why collapse/expand appeared to fix it).
        view.autoResizeDrawable = true
        view.delegate = context.coordinator
        context.coordinator.configure(view: view, theme: theme, background: background)
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.configure(view: uiView, theme: theme, background: background)
        context.coordinator.updateTheme(resolve(theme, style: uiView.traitCollection.userInterfaceStyle))
    }

    public static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        uiView.delegate = nil
        coordinator.stop()
    }

    private func resolve(_ theme: Theme, style: UIUserInterfaceStyle) -> Bool {
        switch theme {
        case .dark: return false
        case .light: return true
        case .system: return style == .light
        }
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        private var renderer: Renderer?
        private var lastBackground: Background?

        fileprivate func configure(view: MTKView, theme: Theme, background: Background) {
            if renderer == nil, let device = view.device {
                renderer = try? Renderer(device: device)
            }
            if lastBackground != background {
                renderer?.setBackground(dark: UIColor(background.dark), light: UIColor(background.light))
                lastBackground = background
            }
            renderer?.updateTheme(theme == .light || (theme == .system && view.traitCollection.userInterfaceStyle == .light))
        }

        fileprivate func updateTheme(_ light: Bool) { renderer?.updateTheme(light) }

        fileprivate func stop() { renderer = nil }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            guard let renderer else { return }
            do { try renderer.draw(in: view) }
            catch { view.isPaused = true }
        }
    }
}

private final class Renderer {
    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var lightMode: Float
        var darkBackground: SIMD4<Float>
        var lightBackground: SIMD4<Float>
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var lastFrameTime = CACurrentMediaTime()
    private var elapsed: Float = 0
    private var currentTheme: Float = 0
    private var targetTheme: Float = 0
    private var darkBackground = SIMD4<Float>(9 / 255, 9 / 255, 9 / 255, 1)
    private var lightBackground = SIMD4<Float>(1, 1, 1, 1)

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw RendererError.commandQueueUnavailable }
        self.queue = queue
        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        guard let vertex = library.makeFunction(name: "openShadersVertex"),
              let fragment = library.makeFunction(name: "openShadersFragment") else {
            throw RendererError.shaderFunctionsUnavailable
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func setBackground(dark: UIColor, light: UIColor) {
        darkBackground = Self.vector(dark)
        lightBackground = Self.vector(light)
    }

    func updateTheme(_ light: Bool) { targetTheme = light ? 1 : 0 }

    func draw(in view: MTKView) throws {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        let now = CACurrentMediaTime()
        let delta = Float(min(max(now - lastFrameTime, 0), 0.1))
        lastFrameTime = now
        if !UIAccessibility.isReduceMotionEnabled { elapsed += delta }
        currentTheme += (targetTheme - currentTheme) * (1 - exp(-delta * 7))
        if abs(targetTheme - currentTheme) < 0.002 { currentTheme = targetTheme }
        var uniforms = Uniforms(
            resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            time: elapsed,
            lightMode: currentTheme,
            darkBackground: darkBackground,
            lightBackground: lightBackground
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private static func vector(_ color: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if !color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
    }

    private enum RendererError: Error { case commandQueueUnavailable, shaderFunctionsUnavailable }

    // Constants and equations are translated from the supplied OpenShaders WebGL2 source.
    private static let shaderSource = #"""
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 resolution;
    float time;
    float lightMode;
    float4 darkBackground;
    float4 lightBackground;
};
struct VertexOut { float4 position [[position]]; };
vertex VertexOut openShadersVertex(uint vertexID [[vertex_id]]) {
    float2 p = float2(float((vertexID << 1) & 2), float(vertexID & 2));
    VertexOut out; out.position = float4(p * 2.0 - 1.0, 0.0, 1.0); return out;
}
float3 oklchToLinear(float L, float C, float h) {
    float a = C * cos(h), b = C * sin(h);
    float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    float s_ = L - 0.0894841775 * a - 1.2914855480 * b;
    float l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    return float3(4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
                  -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
                  -0.0041960863*l - 0.7034186147*m + 1.7076147010*s);
}
float blueNoise(float2 p, float frame) {
    p += 5.588238 * fmod(frame, 64.0);
    return fract(52.9829189 * fract(0.06711056 * p.x + 0.00583715 * p.y));
}
fragment float4 openShadersFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    const float HUE = 0.897649527, HUE_SPREAD = 0.198928982, HUE_TRAVEL = 1.89969957;
    const float CHROMA = 0.123826884, LIGHTNESS = 0.54744786, COLOUR_CYCLE = 0.172139496;
    const float THETA = 2.14129877, SHEAR = 0.961911142, SHRINK = 0.949546337, LAYERS = 82.0;
    const float WARP_FREQ_X = 0.582106292, WARP_FREQ_Y = 2.42119217;
    const float WARP_AMP_X = 0.137306497, WARP_AMP_Y = 0.0340782516;
    const float ASPECT_X = 2.32515025, ASPECT_Y = 0.203835413;
    const float OFFSET_X = 0.329861075, OFFSET_Y = -0.0122578107, TILT = -0.129261211;
    const float ZOOM = 1.16152239, CENTRE_X = -0.268928021, CENTRE_Y = 0.653061152;
    const float GLOW_SIZE = 0.00288019562, FALLOFF = 0.411646336, VIGNETTE = 0.143829599;
    const float FLOW_SPEED = 0.489660144, FLOW_DIRECTION = 1.0, BREATH_RATE = 0.407460213;
    const float BREATH_AMOUNT = 0.0939644203, PHASE = 94.1965103, ECHO = 0.0;
    const float ECHO_SHIFT = 0.166674614, SOFTNESS = 0.00229176646, LIGHT_SWING = 0.227536038;
    const float TAU = 6.28318530718;
    float2 R = u.resolution;
    // Metal's fragment origin is top-left; flip Y to match WebGL's bottom-left gl_FragCoord.
    float2 frag = float2(in.position.x, R.y - in.position.y);
    float2 pos = (frag - 0.5 * R) / R.y;
    float t = u.time * FLOW_SPEED * FLOW_DIRECTION + PHASE;
    float breath = (-sin(u.time * BREATH_RATE * 1.5) + sin(u.time * BREATH_RATE + 1.0)) * 0.25 + 0.5;
    float2 v = (pos - float2(CENTRE_X, CENTRE_Y)) * (ZOOM - breath * BREATH_AMOUNT);
    float ct = cos(TILT), st = sin(TILT);
    v = float2(ct * v.x - st * v.y, st * v.x + ct * v.y);
    float fc = cos(THETA), fs = sin(THETA);
    float hue0 = HUE * TAU, hue1 = hue0 + HUE_SPREAD * TAU;
    float3 rgb = float3(0.0);
    for (int i = 1; i <= 96; ++i) {
        if (float(i) > LAYERS) break;
        v.x += -sin(v.y * WARP_FREQ_X + t + float(i) * 0.007) * WARP_AMP_X;
        v.y += -sin(v.x * WARP_FREQ_Y - t + float(i) * 0.02) * WARP_AMP_Y;
        v = float2(fc * v.x - SHEAR * v.y, fs * v.x + fc * v.y) * SHRINK;
        float2 q = v - float2(OFFSET_X + breath * 0.1, OFFSET_Y);
        float2 s = float2(q.x * ASPECT_X, q.y * ASPECT_Y);
        float glow = GLOW_SIZE / (dot(s, s) + SOFTNESS);
        float2 e = float2((q.x - ECHO_SHIFT) * ASPECT_X, s.y);
        glow += ECHO * GLOW_SIZE / (dot(e, e) + SOFTNESS);
        glow *= 0.25 + breath * 0.4;
        float r = length(v);
        float k = sin(float(i) * COLOUR_CYCLE + t * 1.2 + r * HUE_TRAVEL) * 0.5 + 0.5;
        float3 tint = clamp(oklchToLinear(LIGHTNESS + LIGHT_SWING * k, CHROMA * (0.75 + 0.35 * k), mix(hue0, hue1, k)), 0.0, 1.0);
        rgb += glow * tint * exp2(-r * FALLOFF);
    }
    float3 x = max(rgb, 0.0);
    rgb = (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
    rgb = pow(clamp(rgb, 0.0, 1.0), float3(0.85, 0.92, 0.98));
    float edge = smoothstep(0.5, 1.6, length(pos));
    rgb *= 1.0 - edge * VIGNETTE;
    float3 dark = u.darkBackground.rgb + rgb * (1.0 - u.darkBackground.rgb);
    float strength = max(rgb.r, max(rgb.g, rgb.b));
    float3 light = u.lightBackground.rgb * (1.0 - strength) + rgb * 0.96;
    rgb = mix(dark, light, u.lightMode);
    rgb += (blueNoise(frag, floor(u.time * 24.0)) - 0.5) / 255.0;
    return float4(clamp(rgb, 0.0, 1.0), 1.0);
}
"""#
}

/// Compact card treatment for previewing the native shader with restrained press feedback.
public struct OpenShadersDemoView: View {
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var isPressed = false
    @State private var shellTouchPoint: CGPoint = .zero
    @State private var shellIsTouching = false

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .topLeading) {
                    // Keep the original physical thickness: the reflective plate forms the
                    // backing/side, while the animated shader remains the card face.
                    ReflectiveMetalPlate(
                        touchPoint: $shellTouchPoint,
                        isTouching: $shellIsTouching,
                        tint: SIMD3<Float>(0.34, 0.34, 0.34),
                        theme: 0
                    )
                    .frame(width: size.width, height: size.height)

                    OpenShadersView(theme: .dark)
                        .padding(4)
                        .frame(width: size.width, height: size.height)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(0.13), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.26), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("OpenShaders")
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                Text("A living field of light")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                        Text("LIGHT IN MOTION")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(2.2)
                            .foregroundStyle(.white.opacity(0.76))
                        Text("Open\npossibilities.")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .tracking(-1.1)
                            .lineSpacing(-1)
                            .padding(.top, 8)
                    }
                    .foregroundStyle(.white)
                    .padding(26)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    ReflectiveCardBorder(radius: 24)
                }
                .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 22)
                .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 6)
                .scaleEffect(isPressed ? 0.985 : 1)
                .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                .offset(y: isPressed ? 2 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPressed)
                .animation(.spring(response: 0.32, dampingFraction: 0.76), value: tiltX)
                .animation(.spring(response: 0.32, dampingFraction: 0.76), value: tiltY)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isPressed = true
                            let nx = min(1, max(-1, value.location.x / max(size.width, 1) * 2 - 1))
                            let ny = min(1, max(-1, value.location.y / max(size.height, 1) * 2 - 1))
                            tiltX = -ny * 3.0
                            tiltY = nx * 3.0
                        }
                        .onEnded { _ in
                            isPressed = false
                            tiltX = 0
                            tiltY = 0
                        }
                )
            }
            .frame(width: 320, height: 500)
            .frame(maxWidth: .infinity)

            Text("Press and hold to gently tilt the card")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#endif
