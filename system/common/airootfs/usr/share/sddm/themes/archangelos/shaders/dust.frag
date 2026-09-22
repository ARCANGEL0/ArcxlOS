#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float amp;
    float grainAmt;
} ubo;

layout(binding = 1) uniform sampler2D src;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = ubo.time;


    float region = fbm(vec2(uv.x * 3.4, uv.y * 2.2));
    float sweep = uv.x * 1.15 - uv.y * 0.15;
    float phase = sin((t * 0.55) - sweep * 3.14159 + region * 4.5) * 0.5 + 0.5;


    float dissolve = smoothstep(0.35, 0.95, phase) * (0.45 + 0.35 * region);


    float grain = fbm(vec2(uv.x * 34.0, uv.y * 34.0) + vec2(t * 0.15, -t * 0.1));
    float edge = grain - (1.0 - dissolve);


    float gust = (fbm(vec2(uv.y * 7.0 - t * 0.5, uv.x * 3.0)) - 0.5);
    float carry = clamp(edge, 0.0, 1.0);
    vec2 windOff = vec2(carry * (0.06 + 0.10 * ubo.amp * 12.0), carry * (-0.02 - gust * 0.05));


    float n1 = noise(vec2(uv.y * 6.0 + t * 0.08, uv.y * 3.0 - t * 0.08));
    vec2 shimmer = vec2((n1 - 0.5) * ubo.amp, (n1 - 0.5) * ubo.amp * 0.12);

    vec2 duv = uv + shimmer + windOff;
    vec4 col = texture(src, duv);



    float keep = smoothstep(-0.06, 0.10, edge);
    float mote = (1.0 - smoothstep(0.0, 0.14, abs(edge))) * carry;

    col.a *= keep;

    float spark = step(0.55, grain) * mote;
    col.rgb += vec3(spark * 0.35);
    col.a = clamp(col.a + spark * 0.25, 0.0, 1.0);


    float g = noise(vec2(uv.x * 90.0 + t * 0.5, uv.y * 90.0 - t * 0.2));
    col.a *= mix(1.0, 0.6 + 0.4 * g, ubo.grainAmt);

    fragColor = col * ubo.qt_Opacity;
}
