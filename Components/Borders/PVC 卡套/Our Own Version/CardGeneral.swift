import SwiftUI
import MetalKit
import simd

private struct CardGeneralMetalUniforms {
    var size: SIMD2<Float> = .zero
    var pointer: SIMD2<Float> = .zero
    var tilt: SIMD2<Float> = .zero
    var scale: Float = 3
    var time: Float = 0
    var radius: Float = 24
    var metalness: Float = 1
    var roughness: Float = 0.3
    var blur: Float = 6
    var warp: Float = 0.6
    var warpScale: Float = 1
    var shine: Float = 1
    var bevel: Float = 3
    var glare: Float = 0
    var capture: Float = 0
    var grayscale: Float = 1
    var theme: Float = 0
    var tint: SIMD3<Float> = SIMD3(1, 1, 1)
    var padding: Float = 0
    var presence: Float = 1
    var highlightOnly: Float = 0
    var shapeKind: Float = 0
    var buttonEnabled: Float = 0
    var buttonPressed: Float = 0
}

final class CardGeneralMetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private let queue: MTLCommandQueue
    private var uniforms = CardGeneralMetalUniforms()
    private var targetTilt = SIMD2<Float>(repeating: 0)
    private var currentTilt = SIMD2<Float>(repeating: 0)
    private var targetPointer = SIMD2<Float>(repeating: 0)
    private var currentPointer = SIMD2<Float>(repeating: 0)
    private var targetGlare: Float = 0
    private var currentGlare: Float = 0
    private var lastTime = CACurrentMediaTime()

    private static let shaderSource = #"""
#include <metal_stdlib>
using namespace metal;
struct CardGeneralMetalUniforms { float2 size; float2 pointer; float2 tilt; float scale; float time; float radius; float metalness; float roughness; float blur; float warp; float warpScale; float shine; float bevel; float glare; float capture; float grayscale; float theme; float3 tint; float padding; float presence; float highlightOnly; float shapeKind; float buttonEnabled; float buttonPressed; };
struct RCVertexOut { float4 position [[position]]; float2 uv; };
vertex RCVertexOut rc_vertex(uint id [[vertex_id]]) {
    constexpr float2 p[3] = {float2(-1,-1),float2(3,-1),float2(-1,3)};
    RCVertexOut o; o.position=float4(p[id],0,1); o.uv=p[id]*0.5+0.5; return o;
}
float rc_hash(float2 p) { float3 q=fract(float3(p.xyx)*0.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
float2 rc_hash2(float2 p) { float3 q=fract(float3(p.xyx)*float3(0.1031,0.103,0.0973)); q+=dot(q,q.yzx+33.33); return fract((q.xx+q.yz)*q.zy)*2.0-1.0; }
float3 rc_noise(float2 p) { float2 i=floor(p), f=fract(p), u=f*f*f*(f*(f*6.0-15.0)+10.0), du=30.0*f*f*(f*(f-2.0)+1.0); float2 a=rc_hash2(i),b=rc_hash2(i+float2(1,0)),c=rc_hash2(i+float2(0,1)),d=rc_hash2(i+1); float va=dot(a,f),vb=dot(b,f-float2(1,0)),vc=dot(c,f-float2(0,1)),vd=dot(d,f-1); float k=va-vb-vc+vd; float v=va+u.x*(vb-va)+u.y*(vc-va)+u.x*u.y*k; float2 s=a+u.x*(b-a)+u.y*(c-a)+u.x*u.y*(a-b-c+d)+du*(u.yx*k+float2(vb,vc)-va); return float3(v,s); }
float rc_valueNoise(float2 p) { float2 i=floor(p),f=fract(p),u=f*f*(3-2*f); return mix(mix(rc_hash(i),rc_hash(i+float2(1,0)),u.x),mix(rc_hash(i+float2(0,1)),rc_hash(i+1),u.x),u.y); }
float rc_erf(float x) { float x2=x*x; return sign(x)*sqrt(max(0.0,1.0-exp(-x2*(1.2732395+0.147*x2)/(1.0+0.147*x2)))); }
float rc_band(float x,float hw,float sig) { float s=1.4142136*max(sig,0.0001); return 0.5*(rc_erf((x+hw)/s)-rc_erf((x-hw)/s)); }
float rc_strip(float2 q,float2 c,float2 dir,float hw,float2 sig) { float2 n=float2(-dir.y,dir.x); return rc_band(dot(q-c,n),hw,length(sig*n)); }
float rc_buttonHeight(float2 samplePoint, float2 halfSize, float radius, float height) {
    float2 q = abs(samplePoint) - halfSize + radius;
    float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float edgeProfile = 1.0 - smoothstep(-1.5, 2.5, distance);
    float2 face = samplePoint / halfSize;
    float crownProfile = max(0.0, 1.0 - 0.22 * dot(face, face));
    float faceMask = 1.0 - smoothstep(-2.0, 1.5, distance);
    return height * edgeProfile * mix(1.0, crownProfile, faceMask);
}
fragment float4 rc_fragment(RCVertexOut in [[stage_in]], constant CardGeneralMetalUniforms& u [[buffer(0)]]) {
    constexpr float VIEW = 900.0;
    constexpr float OVERSCAN = 1.2;
    constexpr float CONTENT = 46.0;
    constexpr float2 SWEEP = float2(0.5, 0.86);
    constexpr float3 LUMA = float3(0.2126, 0.7152, 0.0722);
    float2 p = float2(in.uv.x - 0.5, 0.5 - in.uv.y) * u.size;
    float2 halfSize = u.size * 0.5;
    float r = min(u.radius, min(halfSize.x, halfSize.y));
    float2 corner = abs(p) - halfSize + r;
    float2 side = float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    float d; float2 outward;
    if (corner.x > 0.0 && corner.y > 0.0) { d = length(corner) - r; outward = normalize(corner) * side; }
    else if (corner.x > corner.y) { d = corner.x - r; outward = float2(side.x, 0.0); }
    else { d = corner.y - r; outward = float2(0.0, side.y); }
    float coverage = clamp(0.5 - d * u.scale, 0.0, 1.0);
    // A circular content highlight uses a circular SDF, independently of the rim shape.
    if (u.highlightOnly > 0.5 && u.shapeKind > 0.5) {
        float circleRadius = min(halfSize.x, halfSize.y);
        float circleDistance = length(p) - circleRadius;
        coverage = clamp(0.5 - circleDistance * u.scale, 0.0, 1.0);
    }
    float chamferWidth = min(u.bevel, max(r, 1.0));
    float chamfer = chamferWidth > 0.01 ? 1.0 - smoothstep(0.0, chamferWidth, -d) : 0.0;
    float2 slope = outward * chamfer;
    // Embedded rounded-rectangle button height field. Its gradient is folded into
    // the same surface normal used by the existing reflection/highlight pass.
    if (u.buttonEnabled > 0.5) {
        float2 bp = p - float2(0.0, -12.0);
        float2 bHalf = float2(43.0, 16.0);
        float br = 8.0;
        float2 bq = abs(bp) - bHalf + br;
        float bd = length(max(bq, 0.0)) + min(max(bq.x, bq.y), 0.0) - br;
        float buttonHeight = (u.buttonPressed > 0.5 ? 2.0 : 7.0);
        // Derive the normal from the same continuous height field at rest and
        // while pressed. The resulting reflection bends the existing diagonal
        // environment highlight instead of translating the highlight in screen
        // space (which made it appear to travel almost vertically).
        float eps = 1.5;
        float hx = (rc_buttonHeight(bp + float2(eps, 0.0), bHalf, br, buttonHeight) - rc_buttonHeight(bp - float2(eps, 0.0), bHalf, br, buttonHeight)) / (2.0 * eps);
        float hy = (rc_buttonHeight(bp + float2(0.0, eps), bHalf, br, buttonHeight) - rc_buttonHeight(bp - float2(0.0, eps), bHalf, br, buttonHeight)) / (2.0 * eps);
        float normalStrength = (u.buttonPressed > 0.5 ? 1.0 : 1.7);
        slope -= float2(hx, hy) * normalStrength;
    }
    float2 wp = p / (220.0 * u.warpScale);
    float3 w1 = rc_noise(wp); float3 w2 = rc_noise(wp * 2.07 + 13.7);
    float2 ripple = (w1.yz + w2.yz * 0.5) * u.warp; slope += ripple * 0.008;
    float grain = rc_valueNoise(float2(p.x * 0.008, p.y * 0.55)) * 0.45 + rc_valueNoise(float2(p.x * 0.019 + 3.7, p.y * 0.23)) * 0.35 + rc_valueNoise(float2(p.x * 0.004 + 9.2, p.y * 0.09)) * 0.2;
    float brush = u.roughness * u.roughness; slope.y += (grain - 0.5) * brush * 0.004;
    float cx = cos(u.tilt.x), sx = sin(u.tilt.x), cy = cos(u.tilt.y), sy = sin(u.tilt.y);
    float3x3 rotation = float3x3(float3(cy, sx * sy, -cx * sy), float3(0.0, cx, sx), float3(sy, -sx * cy, cx * cy));
    float3 normal = rotation * normalize(float3(slope, 1.0));
    float3 position = rotation * float3(p, 0.0);
    float3 view = normalize(position - float3(0.0, 0.0, VIEW));
    float3 bounce = reflect(view, normal); float2 q = bounce.xy / max(bounce.z, 0.2);
    float2 footprint = fwidth(q);
    float2 sigma = sqrt(float2(u.blur / VIEW) * float2(u.blur / VIEW) + footprint * footprint * 0.5);
    sigma += float2(0.004, 0.05) * u.roughness;
    float2 shift = clamp((q - p / VIEW) * CONTENT + ripple * 10.0, -u.size, u.size);
    float2 cp = (p + shift) / (u.size * OVERSCAN);
    // Original default uses the procedural room when no video/camera environment is supplied.
    float fall = smoothstep(-0.55, 0.5, q.y);
    float2 dir = normalize(SWEEP); float2 nrm = float2(-dir.y, dir.x);
    float flagX = dot(q - float2(0.24, -0.02), nrm);
    float flagS = 1.4142136 * max(length((sigma + 0.08) * nrm), 0.0001);
    float flag = 0.5 * (rc_erf((flagX + 0.09) / flagS) - rc_erf((flagX - 0.09) / flagS));
    float scene = mix(0.85, 0.12, fall) * (1.0 - 0.6 * flag);
    scene *= 1.0 + (grain - 0.5) * brush * 0.3;
    float keyX = dot(q - float2(-0.1, -0.16), nrm); float keyS = 1.4142136 * max(length((sigma + 0.018) * nrm), 0.0001);
    float key = 0.5 * (rc_erf((keyX + 0.022) / keyS) - rc_erf((keyX - 0.022) / keyS));
    float top = 0.5 * (rc_erf((q.y + 0.6 + 0.12) / (1.4142136 * max(sigma.y + 0.05, 0.0001))) - rc_erf((q.y + 0.6 - 0.12) / (1.4142136 * max(sigma.y + 0.05, 0.0001))));
    float edge = 0.5 * (rc_erf((q.x - 0.46 + 0.05) / (1.4142136 * max(sigma.x + 0.05, 0.0001))) - rc_erf((q.x - 0.46 - 0.05) / (1.4142136 * max(sigma.x + 0.05, 0.0001))));
    float2 toPointer = (u.pointer - p) / (120.0 + u.blur * 4.0);
    float2 spread = toPointer * float2(1.0, 1.0 / (1.0 + 2.5 * u.roughness));
    float reach = dot(spread, spread); float glint = max(1.0 + 3.0 * dot(slope, toPointer), 0.0);
    float glare = (exp(-reach * 1.6) + exp(-reach * 0.35) * 0.15) * glint * u.glare * (1.0 + 0.8 * (grain - 0.5) * brush);
    // The embedded button does not get a separately painted specular stripe.
    // Its height-field gradient above changes the shared surface normal, so the
    // existing environment key is reflected through the same lighting equation.
    // This keeps the highlight causally tied to the card's diagonal light source.
    float highlight = (key + top * 0.8 + edge * 0.35) * u.shine + glare;
    highlight *= mix(0.4, 1.0, u.metalness);
    float3 dark = float3(0.005, 0.005, 0.006) + u.tint * (scene * 0.05 * u.metalness + highlight * 0.36);
    float3 light = u.tint * (float3(0.83, 0.83, 0.85) * (1.0 - 0.45 * u.metalness * (1.0 - clamp(scene, 0.0, 1.0))) + highlight * 0.35);
    float3 color = mix(dark, light, u.theme);
    color = min(color, 0.7) + 0.3 * (1.0 - exp(-max(color - 0.7, 0.0) / 0.3));
    color = pow(clamp(color, 0.0, 1.0), float3(1.0 / 2.2));
    color += (rc_hash(in.position.xy) - 0.5) / 255.0; color = clamp(color, 0.0, 1.0);
    if (u.highlightOnly > 0.5) {
        // Extract the highlight's color contribution from the original dark/light
        // material equations. Keep tint, theme and metalness in the same path as
        // the original shader instead of painting a generic translucent white.
        float3 highlightContribution = mix(
            u.tint * (highlight * 0.36),
            u.tint * (highlight * 0.35),
            u.theme
        ) * mix(0.4, 1.0, u.metalness);
        float highlightLuma = dot(max(highlightContribution, float3(0.0)), LUMA);
        float highlightAlpha = clamp(highlightLuma * 1.8, 0.0, 0.82) * coverage;
        float3 highlightColor = highlightLuma > 0.0001
            ? clamp(highlightContribution / max(highlightLuma, 0.0001), 0.0, 1.0)
            : float3(0.0);
        return float4(highlightColor * highlightAlpha, highlightAlpha);
    }
    return float4(color * coverage, coverage);
}
"""#

    init?(view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(), let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
              let vertex = library.makeFunction(name: "rc_vertex"), let fragment = library.makeFunction(name: "rc_fragment"),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device; self.queue = queue
        let descriptor = MTLRenderPipelineDescriptor(); descriptor.vertexFunction = vertex; descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one; descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one; descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        pipeline = state
        super.init()
        view.device = device; view.delegate = self; view.isPaused = false; view.enableSetNeedsDisplay = false
        view.framebufferOnly = true; view.backgroundColor = .clear; view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    func aim(_ point: CGPoint, in size: CGSize, active: Bool) {
        let nx = Float((point.x / max(size.width, 1)) * 2 - 1)
        let ny = Float((point.y / max(size.height, 1)) * 2 - 1)
        targetTilt = active ? SIMD2(nx, ny) : .zero
        targetPointer = SIMD2(nx * Float(size.width) * 0.5, -ny * Float(size.height) * 0.5)
        targetGlare = active ? 0.5 : 0
    }

    func setPalette(tint: SIMD3<Float>, theme: Float) { uniforms.tint = tint; uniforms.theme = theme }
    func setEmbeddedButton(enabled: Bool, pressed: Bool) { uniforms.buttonEnabled = enabled ? 1 : 0; uniforms.buttonPressed = pressed ? 1 : 0 }
    func setHighlightOnly(_ enabled: Bool, shapeKind: Float, shine: Float, blur: Float, glare: Float) {
        uniforms.highlightOnly = enabled ? 1 : 0
        uniforms.shapeKind = shapeKind
        uniforms.shine = max(0, shine)
        uniforms.blur = max(0, blur)
        uniforms.glare = max(0, glare)
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { uniforms.size = SIMD2(Float(size.width), Float(size.height)) }
    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable, let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        let now = CACurrentMediaTime(), dt = Float(min(0.05, now-lastTime)); lastTime = now
        let blend = 1 - exp(-dt * 12)
        currentTilt += (targetTilt-currentTilt)*blend; currentPointer += (targetPointer-currentPointer)*blend; currentGlare += (targetGlare-currentGlare)*blend
        uniforms.size = SIMD2(Float(view.bounds.width), Float(view.bounds.height))
        uniforms.scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
        uniforms.tilt = SIMD2(currentTilt.y * 0.20943951, -currentTilt.x * 0.20943951)
        uniforms.pointer = currentPointer; uniforms.glare = currentGlare
        encoder.setRenderPipelineState(pipeline); encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CardGeneralMetalUniforms>.stride, index: 0); encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); encoder.endEncoding(); command.present(drawable); command.commit()
    }
}

struct CardGeneralMetalPlate: UIViewRepresentable {
    @Binding var touchPoint: CGPoint
    @Binding var isTouching: Bool
    var tint: SIMD3<Float> = SIMD3(1, 1, 1)
    var theme: Float = 0
    var highlightOnly: Bool = false
    var highlightShine: Float = 1
    var highlightBlur: Float = 6
    var highlightGlare: Float = 0
    var highlightUsesCircle: Bool = false
    var embeddedButtonEnabled: Bool = false
    var embeddedButtonPressed: Bool = false
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice()); view.isOpaque = false; view.preferredFramesPerSecond = 60
        context.coordinator.renderer = CardGeneralMetalRenderer(view: view)
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.aim(touchPoint, in: view.bounds.size, active: isTouching)
        context.coordinator.renderer?.setPalette(tint: tint, theme: theme)
        context.coordinator.renderer?.setEmbeddedButton(enabled: embeddedButtonEnabled, pressed: embeddedButtonPressed)
        context.coordinator.renderer?.setHighlightOnly(highlightOnly, shapeKind: highlightUsesCircle ? 1 : 0, shine: highlightShine, blur: highlightBlur, glare: highlightGlare)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: CardGeneralMetalRenderer? }
}


/// A content-free shell around the self-contained native Metal renderer.
/// Surface, rim, highlights and shadows are implemented locally in this file.
public enum CardGeneralPalette: String, CaseIterable, Identifiable {
    case graphite, pearl, sapphire, amethyst, rose, emerald
    public var id: String { rawValue }

    fileprivate var tint: SIMD3<Float> {
        switch self {
        case .graphite, .pearl: SIMD3(1, 1, 1)
        case .sapphire: SIMD3(0.52, 0.72, 1)
        case .amethyst: SIMD3(0.83, 0.63, 1)
        case .rose: SIMD3(1, 0.64, 0.72)
        case .emerald: SIMD3(0.53, 0.92, 0.72)
        }
    }
    fileprivate var theme: Float { self == .pearl ? 1 : 0 }
}

public struct CardGeneral<S: Shape, Content: View>: View {
    private let shape: S
    private let palette: CardGeneralPalette
    private let thickness: CGFloat
    private let shadowIntensity: Double
    private let content: Content
    private let showsCenterHighlights: Bool
    private let centerHighlightOpacity: Double
    private let centerHighlightShine: Float
    private let centerHighlightBlur: Float
    private let centerHighlightGlare: Float
    private let centerHighlightUsesCircle: Bool
    private let embeddedButtonEnabled: Bool
    private let embeddedButtonPressed: Bool
    private let onEmbeddedButtonTap: () -> Void
    @State private var touchPoint: CGPoint = .zero
    @State private var isTouching = false
    @State private var gestureStartedOnButton = false
    @State private var gestureInProgress = false
    @State private var isEmbeddedButtonDown = false
    @State private var gestureStartLocation: CGPoint = .zero

    public init(
        shape: S,
        thickness: CGFloat = 6,
        palette: CardGeneralPalette = .pearl,
        shadowIntensity: Double = 1,
        showsCenterHighlights: Bool = false,
        centerHighlightOpacity: Double = 0.7,
        centerHighlightShine: Float = 1,
        centerHighlightBlur: Float = 6,
        centerHighlightGlare: Float = 0,
        centerHighlightUsesCircle: Bool = false,
        embeddedButtonEnabled: Bool = false,
        embeddedButtonPressed: Bool = false,
        onEmbeddedButtonTap: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.shape = shape
        self.palette = palette
        self.thickness = max(1, thickness)
        self.shadowIntensity = min(max(shadowIntensity, 0), 1)
        self.showsCenterHighlights = showsCenterHighlights
        self.centerHighlightOpacity = min(max(centerHighlightOpacity, 0), 1)
        self.centerHighlightShine = centerHighlightShine
        self.centerHighlightBlur = centerHighlightBlur
        self.centerHighlightGlare = centerHighlightGlare
        self.centerHighlightUsesCircle = centerHighlightUsesCircle
        self.embeddedButtonEnabled = embeddedButtonEnabled
        self.embeddedButtonPressed = embeddedButtonPressed
        self.onEmbeddedButtonTap = onEmbeddedButtonTap
        self.content = content()
    }

    private func isInsideEmbeddedButton(_ point: CGPoint, size: CGSize) -> Bool {
        // Use a generous hit target around the visually rendered center button.
        // The shader's material can visually shift the apparent button edge, so
        // the interactive target intentionally exceeds the 86 × 32 relief field.
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5 + 12
        return abs(point.x - centerX) <= 64 && abs(point.y - centerY) <= 48
    }

    public var body: some View {
        content
            .clipShape(shape)
            .overlay {
                ZStack {
                    CardGeneralMetalPlate(touchPoint: $touchPoint, isTouching: $isTouching, tint: palette.tint, theme: palette.theme, embeddedButtonEnabled: embeddedButtonEnabled, embeddedButtonPressed: embeddedButtonPressed || isEmbeddedButtonDown)
                        .mask { shape.stroke(lineWidth: thickness * 0.25) }

                    // Separate highlight pass, using the selected palette rather than a hard-coded white tint.
                    if showsCenterHighlights {
                        CardGeneralMetalPlate(
                            touchPoint: $touchPoint,
                            isTouching: $isTouching,
                            tint: palette.tint,
                            theme: palette.theme,
                            highlightOnly: true,
                            highlightShine: centerHighlightShine,
                            highlightBlur: centerHighlightBlur,
                            highlightGlare: centerHighlightGlare,
                            highlightUsesCircle: centerHighlightUsesCircle,
                            embeddedButtonEnabled: embeddedButtonEnabled,
                            embeddedButtonPressed: embeddedButtonPressed || isEmbeddedButtonDown
                        )
                        .opacity(centerHighlightOpacity)
                    }
                }
                .allowsHitTesting(false)
            }
            // Shadow intensity is intentionally applied only to the two shadow passes.
            .shadow(color: .black.opacity((palette == .pearl ? 0.12 : 0.55) * shadowIntensity), radius: 22, x: 0, y: 22)
            .shadow(color: .black.opacity((palette == .pearl ? 0.08 : 0.30) * shadowIntensity), radius: 8, x: 0, y: 6)
            .contentShape(shape)
            .overlay {
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !gestureInProgress {
                                    gestureInProgress = true
                                    gestureStartLocation = value.startLocation
                                    gestureStartedOnButton = embeddedButtonEnabled && isInsideEmbeddedButton(value.startLocation, size: geometry.size)
                                    isEmbeddedButtonDown = gestureStartedOnButton
                                    // Reset the previous card-drag state at the beginning
                                    // of every touch, including taps on the button.
                                    isTouching = false
                                }
                                if !gestureStartedOnButton {
                                    touchPoint = value.location
                                    isTouching = true
                                }
                            }
                            .onEnded { value in
                                if gestureStartedOnButton {
                                    let dx = value.location.x - gestureStartLocation.x
                                    let dy = value.location.y - gestureStartLocation.y
                                    if dx * dx + dy * dy < 144 { onEmbeddedButtonTap() }
                                }
                                isTouching = false
                                isEmbeddedButtonDown = false
                                gestureStartedOnButton = false
                                gestureInProgress = false
                            }
                        )
                }
            }
    }
}

public extension View {
    func cardGeneral<S: Shape>(
        shape: S,
        thickness: CGFloat = 6,
        palette: CardGeneralPalette = .pearl,
        shadowIntensity: Double = 1,
        showsCenterHighlights: Bool = false,
        centerHighlightOpacity: Double = 0.7,
        centerHighlightShine: Float = 1,
        centerHighlightBlur: Float = 6,
        centerHighlightGlare: Float = 0,
        centerHighlightUsesCircle: Bool = false,
        embeddedButtonEnabled: Bool = false,
        embeddedButtonPressed: Bool = false,
        onEmbeddedButtonTap: @escaping () -> Void = {}
    ) -> some View {
        CardGeneral(
            shape: shape,
            thickness: thickness,
            palette: palette,
            shadowIntensity: shadowIntensity,
            showsCenterHighlights: showsCenterHighlights,
            centerHighlightOpacity: centerHighlightOpacity,
            centerHighlightShine: centerHighlightShine,
            centerHighlightBlur: centerHighlightBlur,
            centerHighlightGlare: centerHighlightGlare,
            centerHighlightUsesCircle: centerHighlightUsesCircle,
            embeddedButtonEnabled: embeddedButtonEnabled,
            embeddedButtonPressed: embeddedButtonPressed,
            onEmbeddedButtonTap: onEmbeddedButtonTap
        ) { self }
    }
}
