#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Turns the blurred alpha field into a connected, softly edged liquid silhouette.
[[ stitchable ]] half4 liquidBlobAlphaThreshold(float2 position, SwiftUI::Layer layer, float threshold, float softness) {
    half4 sampleColor = layer.sample(position);
    float sourceAlpha = float(sampleColor.a);
    float mergedAlpha = smoothstep(threshold, threshold + max(softness, 0.001), sourceAlpha);
    float3 straightRGB = float3(sampleColor.rgb) / max(sourceAlpha, 0.0001);
    return half4(half3(straightRGB * mergedAlpha), half(mergedAlpha));
}
