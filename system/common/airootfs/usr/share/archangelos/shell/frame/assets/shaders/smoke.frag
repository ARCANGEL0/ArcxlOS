#version 440
// ArchangelOS: black smoke around the shell's frame. `src` is the frame's silhouette, blurred;
// it is pushed around by domain-warped fbm noise so the shadow curls off every edge and notch
// like smoke instead of sitting there as a flat drop shadow. Rebuild with
//   qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o smoke.frag.qsb smoke.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size in px
    float time;      // seconds, drifting
    float strength;  // 0..1 overall density
    float reach;     // px the smoke may be pushed off the silhouette
    vec4 tint;       // smoke colour
};
layout(binding = 1) uniform sampler2D src;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + vec2(17.0, 9.0); a *= 0.5; }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * res / 260.0;
    float t = time;
    // domain warp: two slow fields steer the lookup, a third one breaks the density up
    vec2 q = vec2(fbm(p + vec2(0.0, t * 0.045)), fbm(p + vec2(5.2, 1.3) - vec2(t * 0.035, 0.0)));
    vec2 warp = (q - 0.5) * 2.0 * reach / res;
    float a = texture(src, uv + warp).a;
    float n = fbm(p * 1.6 + q * 2.2 + vec2(t * 0.02, -t * 0.03));
    // soft haze, densest against the frame, thinning into wisps further out
    float smoke = smoothstep(0.0, 1.0, pow(a, 1.25) * (0.45 + 0.95 * n));
    fragColor = vec4(tint.rgb, 1.0) * tint.a * smoke * strength * qt_Opacity;
}
