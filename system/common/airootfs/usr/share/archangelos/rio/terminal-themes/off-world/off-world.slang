#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float glow;
	float grade;
} params;

#pragma parameter glow "Glow" 1.0 0.0 2.0 0.05
#pragma parameter grade "Cyan Grade" 0.55 0.0 1.0 0.05

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = vec2(TexCoord.x, 1.0 - TexCoord.y);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D accum1;
layout(set = 0, binding = 4) uniform sampler2D blur2;

#define CYAN   vec3(0.42, 0.90, 1.00)
#define DEEP   vec3(0.014, 0.040, 0.052)
#define STEEL  vec3(0.16, 0.30, 0.34)

vec3 fetch(sampler2D tex, vec2 uv)
{
	return texture(tex, vec2(uv.x, 1.0 - uv.y)).rgb;
}

float luma(vec3 c)
{
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p)
{
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float line(float x, float w)
{
	return 1.0 - smoothstep(w, w + 1.0, abs(x));
}

void main()
{
	float t = float(params.FrameCount) / 60.0;
	vec2 uv = vTexCoord;
	vec2 res = params.OutputSize.xy;
	vec2 px = uv * res;

	vec3 src = fetch(accum1, uv);
	vec3 bloom = fetch(blur2, uv);
	float ink = smoothstep(0.05, 0.35, luma(src));

	vec3 graded = mix(src, CYAN * luma(src) * 1.25, params.grade);
	graded = mix(graded, graded * vec3(0.92, 1.0, 1.06), 0.5);

	float grime = noise(px / 180.0) * 0.6 + noise(px / 46.0) * 0.4;
	vec3 col = DEEP * (0.75 + 0.5 * grime);
	col += graded * 1.1;
	col += CYAN * luma(bloom) * 0.55 * params.glow;
	col += CYAN * pow(luma(bloom), 2.0) * 0.9 * params.glow;

	col *= 0.93 + 0.07 * sin(px.y * 3.14159265);
	col += (hash(floor(px) + floor(t * 24.0)) - 0.5) * 0.028;
	col *= 0.985 + 0.015 * sin(t * 31.0);

	vec2 v = uv - 0.5;
	col *= 1.0 - 0.45 * pow(clamp(length(v * vec2(1.0, 1.25)) * 1.25, 0.0, 1.0), 2.2);

	float dx = min(px.x, res.x - px.x);
	float dy = min(px.y, res.y - px.y);
	float edge = min(dx, dy);

	float outer = line(edge - 6.5, 0.4);
	float inner = line(edge - 11.5, 0.3);
	float tickLen = 30.0;
	float corner = step(dx, tickLen) * step(dy, tickLen);
	float ticks = corner * max(line(dx - 6.5, 1.0) * step(dy, tickLen), line(dy - 6.5, 1.0) * step(dx, tickLen));
	float marks = line(edge - 9.0, 0.0) * step(0.5, fract((px.x + px.y) / 64.0)) * step(edge, 9.5);

	float plate = 1.0 - smoothstep(6.0, 7.0, edge);
	col = mix(col, DEEP * 0.5, plate);
	col += STEEL * outer * 0.9 + CYAN * inner * 0.22 + CYAN * ticks * 0.75 + STEEL * marks * 0.5;
	col += CYAN * exp(-max(edge - 7.0, 0.0) * 0.06) * 0.03;

	col = clamp(col, 0.0, 1.0);
	float alpha = 0.86 + 0.14 * clamp(ink * 2.0 + plate + ticks, 0.0, 1.0);
	FragColor = vec4(col * alpha, alpha);
}
