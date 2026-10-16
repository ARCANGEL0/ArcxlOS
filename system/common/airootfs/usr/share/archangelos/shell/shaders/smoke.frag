#version 440

// Reveals a panel as if it flows out of the sidebar: the leading edge is a
// ragged band of noise that darkens into black smoke before clearing. Once
// open, a faint smoke drifts through the panel's surface.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;   // 0 hidden .. 1 fully revealed
    float time;       // seconds, drives the drift
    float aspect;     // item width / height
    float ambient;    // strength of the resting smoke drift
} ubo;

layout(binding = 1) uniform sampler2D source;

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
    vec4 c = texture(source, uv);

    vec2 q = vec2(uv.x * ubo.aspect, uv.y) * 2.6;
    // Broad billows plus fine tendrils, both drifting away from the sidebar.
    float n = 0.6 * fbm(q + vec2(-ubo.time * 0.22, ubo.time * 0.06))
            + 0.4 * fbm(q * 4.5 + vec2(-ubo.time * 0.6, ubo.time * 0.15));

    // The reveal front travels away from the sidebar (uv.x = 0).
    const float feather = 0.32;
    float front = ubo.progress * (1.0 + 2.2 * feather);
    float d = front - uv.x - (n - 0.5) * 2.2 * feather;
    float reveal = smoothstep(0.0, feather * 0.22, d);

    // Thick black smoke just behind the front, thinning as it settles.
    float band = reveal * (1.0 - smoothstep(feather * 0.25, feather * 1.4, d));
    vec3 rgb = mix(c.rgb, vec3(0.0), clamp(band * 0.92, 0.0, 1.0));

    // Resting drift: soft lighter wisps over the ink, masked to the surface.
    float wisp = smoothstep(0.52, 0.85, fbm(q * 0.7 + vec2(ubo.time * 0.05, -ubo.time * 0.03)));
    rgb += vec3(wisp * ubo.ambient) * c.a;

    fragColor = vec4(rgb, c.a) * reveal * ubo.qt_Opacity;
}
