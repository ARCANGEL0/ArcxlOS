#version 440

// Black smoke billowing around a panel while it opens or closes. Draws
// nothing at rest; strongest mid-transition.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float intensity;  // 0..1, typically sin(pi * progress)
    float time;
    float aspect;
    vec4 box;         // panel rect in this item's uv: x0, y0, x1, y1
} ubo;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * ubo.aspect, uv.y);

    // Distance outside the panel rect (0 inside).
    vec2 o = max(ubo.box.xy - uv, uv - ubo.box.zw);
    float dist = length(max(o, 0.0));

    // Smoke rolls outward, away from the sidebar.
    float n = fbm(p * 3.2 + vec2(-ubo.time * 0.55, ubo.time * 0.18));
    float m = fbm(p * 7.0 + vec2(-ubo.time * 0.9, -ubo.time * 0.25));
    float reach = 0.05 + 0.13 * n;
    float body = 1.0 - smoothstep(0.0, reach, dist);

    float density = smoothstep(0.32, 0.72, n * 0.75 + m * 0.35) * body * ubo.intensity;
    // A faint grey rim keeps black smoke legible over dark wallpapers.
    float rim = smoothstep(0.55, 0.62, n) * (1.0 - smoothstep(0.62, 0.75, n));
    vec3 rgb = vec3(0.10) * rim * density;

    fragColor = vec4(rgb, density * 0.88) * ubo.qt_Opacity;
}
