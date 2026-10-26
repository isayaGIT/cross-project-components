import SwiftUI
import MetalKit
import simd

private struct RCUniforms {
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
}

final class ReflectiveCardRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private let queue: MTLCommandQueue
    private var uniforms = RCUniforms()
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
struct RCUniforms { float2 size; float2 pointer; float2 tilt; float scale; float time; float radius; float metalness; float roughness; float blur; float warp; float warpScale; float shine; float bevel; float glare; float capture; float grayscale; float theme; float3 tint; float padding; float presence; };
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
fragment float4 rc_fragment(RCVertexOut in [[stage_in]], constant RCUniforms& u [[buffer(0)]]) {
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
    float chamferWidth = min(u.bevel, max(r, 1.0));
    float chamfer = chamferWidth > 0.01 ? 1.0 - smoothstep(0.0, chamferWidth, -d) : 0.0;
    float2 slope = outward * chamfer;
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
    float highlight = (key + top * 0.8 + edge * 0.35) * u.shine + glare;
    highlight *= mix(0.4, 1.0, u.metalness);
    float3 dark = float3(0.005, 0.005, 0.006) + u.tint * (scene * 0.05 * u.metalness + highlight * 0.36);
    float3 light = u.tint * (float3(0.83, 0.83, 0.85) * (1.0 - 0.45 * u.metalness * (1.0 - clamp(scene, 0.0, 1.0))) + highlight * 0.35);
    float3 color = mix(dark, light, u.theme);
    color = min(color, 0.7) + 0.3 * (1.0 - exp(-max(color - 0.7, 0.0) / 0.3));
    color = pow(clamp(color, 0.0, 1.0), float3(1.0 / 2.2));
    color += (rc_hash(in.position.xy) - 0.5) / 255.0; color = clamp(color, 0.0, 1.0);
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
        encoder.setRenderPipelineState(pipeline); encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RCUniforms>.stride, index: 0); encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); encoder.endEncoding(); command.present(drawable); command.commit()
    }
}

struct ReflectiveMetalPlate: UIViewRepresentable {
    @Binding var touchPoint: CGPoint
    @Binding var isTouching: Bool
    var tint: SIMD3<Float> = SIMD3(1, 1, 1)
    var theme: Float = 0
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice()); view.isOpaque = false; view.preferredFramesPerSecond = 60
        context.coordinator.renderer = ReflectiveCardRenderer(view: view)
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.aim(touchPoint, in: view.bounds.size, active: isTouching)
        context.coordinator.renderer?.setPalette(tint: tint, theme: theme)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: ReflectiveCardRenderer? }
}

/// Native translation of the original CSS inset rim:
/// inset 0 0 0 1px var(--rc-rim), inset 0 1px 0 var(--rc-rim-highlight).
public struct ReflectiveCardBorder: View {
    public var radius: CGFloat
    public var rimColor: Color
    public var highlightColor: Color

    public init(radius: CGFloat = 24, rimColor: Color = .white.opacity(0.07), highlightColor: Color = .white.opacity(0.10)) {
        self.radius = radius
        self.rimColor = rimColor
        self.highlightColor = highlightColor
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(rimColor, lineWidth: 1)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(highlightColor, lineWidth: 1)
                    // Keep the highlight on the rounded outline, but confine it to
                    // a narrow strip at the top so it cannot read as a white patch.
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.012),
                                .init(color: .clear, location: 0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .allowsHitTesting(false)
    }
}

struct ReflectiveCardPreview: View {
    @State private var touchPoint: CGPoint = .zero
    @State private var isTouching = false
    @State private var isCollapsed = false
    @State private var selectedPalette = 0
    private let palettes: [(name: String, tint: Color, base: Color, ink: Color, muted: Color, tileTop: Color, tileBottom: Color, theme: Float)] = [
        ("Obsidian", Color.white, Color(red: 0.114, green: 0.110, blue: 0.133), Color(red: 0.957, green: 0.957, blue: 0.961), Color.white.opacity(0.6), Color(red: 0.227, green: 0.212, blue: 0.267), Color(red: 0.153, green: 0.141, blue: 0.184), 0),
        ("Pearl", Color.white, Color(red: 0.906, green: 0.906, blue: 0.918), Color(red: 0.094, green: 0.094, blue: 0.106), Color.black.opacity(0.6), .white, Color(red: 0.965, green: 0.965, blue: 0.976), 1),
        ("Sapphire", Color(red: 0.52, green: 0.72, blue: 1), Color(red: 0.055, green: 0.10, blue: 0.20), Color(red: 0.91, green: 0.95, blue: 1), Color(red: 0.65, green: 0.75, blue: 0.9), Color(red: 0.12, green: 0.22, blue: 0.38), Color(red: 0.07, green: 0.13, blue: 0.25), 0),
        ("Amethyst", Color(red: 0.83, green: 0.63, blue: 1), Color(red: 0.15, green: 0.08, blue: 0.20), Color(red: 0.97, green: 0.92, blue: 1), Color(red: 0.78, green: 0.68, blue: 0.84), Color(red: 0.32, green: 0.19, blue: 0.40), Color(red: 0.20, green: 0.11, blue: 0.27), 0),
        ("Rose", Color(red: 1, green: 0.64, blue: 0.72), Color(red: 0.20, green: 0.075, blue: 0.12), Color(red: 1, green: 0.93, blue: 0.95), Color(red: 0.88, green: 0.67, blue: 0.73), Color(red: 0.39, green: 0.17, blue: 0.24), Color(red: 0.25, green: 0.10, blue: 0.16), 0),
        ("Emerald", Color(red: 0.53, green: 0.92, blue: 0.72), Color(red: 0.045, green: 0.14, blue: 0.11), Color(red: 0.90, green: 1, blue: 0.95), Color(red: 0.62, green: 0.82, blue: 0.74), Color(red: 0.11, green: 0.30, blue: 0.23), Color(red: 0.06, green: 0.19, blue: 0.14), 0)
    ]
    private var palette: (name: String, tint: Color, base: Color, ink: Color, muted: Color, tileTop: Color, tileBottom: Color, theme: Float) { palettes[selectedPalette] }
    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 500
    private let radius: CGFloat = 24

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(Array(palettes.enumerated()), id: \.offset) { index, item in
                    Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { selectedPalette = index } } label: {
                        Circle().fill(item.tint == .white ? item.base : item.tint).frame(width: 25, height: 25)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(selectedPalette == index ? 0.9 : 0.12), lineWidth: selectedPalette == index ? 2 : 1))
                            .padding(3).background(Circle().strokeBorder(Color.primary.opacity(selectedPalette == index ? 0.35 : 0), lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel(item.name)
                }
                Spacer(minLength: 0)
                Button { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { isCollapsed.toggle(); isTouching = false } } label: {
                    Image(systemName: isCollapsed ? "arrow.up.left.and.arrow.down.right" : "minus.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 34, height: 34).background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(isCollapsed ? "Expand card" : "Collapse card")
            }
            GeometryReader { proxy in
                let scale = min(1, (proxy.size.width - 4) / cardWidth)
                Group {
                    if isCollapsed {
                        Button { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { isCollapsed = false } } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.base)
                                ReflectiveMetalPlate(touchPoint: $touchPoint, isTouching: $isTouching, tint: SIMD3(Float(palette.tint.components.red), Float(palette.tint.components.green), Float(palette.tint.components.blue)), theme: palette.theme).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }.frame(width: 72, height: 88).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(palette.ink.opacity(0.12), lineWidth: 1)).shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                        }.buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        card.frame(width: cardWidth, height: cardHeight).scaleEffect(scale)
                            .frame(width: cardWidth * scale, height: cardHeight * scale).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }.frame(height: 500 * min(1, (UIScreen.main.bounds.width - 48) / 320))
            Text(isCollapsed ? "Tap the card to expand" : "Tap an empty area of the card to collapse")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 16))
                Text("Verified").font(.system(size: 13, weight: .medium))
                Spacer()
                HStack(spacing: 8) { Circle().fill(Color(red: 0.133, green: 0.773, blue: 0.369)).frame(width: 6, height: 6); Text("Active").font(.system(size: 13)).foregroundStyle(palette.muted) }
            }.foregroundStyle(palette.ink)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("Alexander Doe").font(.system(size: 24, weight: .medium)).tracking(-0.48).lineLimit(2).foregroundStyle(palette.ink)
                Text("Senior Developer").font(.system(size: 14)).foregroundStyle(palette.muted)
            }
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID number").font(.system(size: 12)).foregroundStyle(palette.muted)
                    Text("8901 2345 6789").font(.system(size: 15, design: .monospaced)).tracking(0.3).lineLimit(1).minimumScaleFactor(0.75).foregroundStyle(palette.ink)
                }
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LinearGradient(colors: [palette.tileTop, palette.tileBottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.ink.opacity(0.09), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
            }.padding(.top, 24)
        }
        .padding(19).frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(palette.base)
                ReflectiveMetalPlate(touchPoint: $touchPoint, isTouching: $isTouching, tint: SIMD3(Float(palette.tint.components.red), Float(palette.tint.components.green), Float(palette.tint.components.blue)), theme: palette.theme).clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
        .overlay {
            ReflectiveCardBorder(
                radius: radius,
                rimColor: selectedPalette == 1 ? Color(red: 24 / 255, green: 24 / 255, blue: 27 / 255).opacity(0.08) : palette.ink.opacity(0.07),
                highlightColor: selectedPalette == 1 ? Color.white.opacity(0.80) : palette.ink.opacity(0.10)
            )
        }
        .shadow(color: .black.opacity(selectedPalette == 1 ? 0.12 : 0.55), radius: 22, x: 0, y: 22)
        .shadow(color: .black.opacity(selectedPalette == 1 ? 0.08 : 0.3), radius: 8, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: radius))
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { value in touchPoint = value.location; isTouching = true }.onEnded { value in
            isTouching = false
            guard hypot(value.translation.width, value.translation.height) < 8 else { return }
            let p = value.location
            let inHeader = p.y < 55
            let inFooter = p.y > cardHeight - 100
            let inIdentity = p.y > cardHeight - 180 && p.y < cardHeight - 100
            if !inHeader && !inFooter && !inIdentity { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { isCollapsed = true } }
        })
    }
}

private extension Color {
    var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (1, 1, 1)
        #endif
    }
}
