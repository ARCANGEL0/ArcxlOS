#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float grid;
} params;

#pragma parameter grid "Dot Grid" 1.0 0.0 2.0 0.05

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

#define PAPER   vec3(0.937, 0.937, 0.929)
#define GRAPHITE vec3(0.27, 0.29, 0.31)
#define HAIR    vec3(0.62, 0.63, 0.64)
#define ORANGE  vec3(1.00, 0.30, 0.11)

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

float line(float x, float w)
{
	return 1.0 - smoothstep(w, w + 1.0, abs(x));
}

float rect(vec2 p, vec2 a, vec2 b)
{
	return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y);
}

void main()
{
	float t = float(params.FrameCount) / 60.0;
	vec2 uv = vTexCoord;
	vec2 res = params.OutputSize.xy;
	vec2 px = uv * res;
	vec2 fromTop = vec2(px.x, res.y - px.y);

	vec3 src = fetch(Source, uv);
	float paperness = smoothstep(0.80, 0.92, luma(src));

	vec2 cell = mod(px, 22.0) - 11.0;
	float pip = 1.0 - smoothstep(0.6, 1.3, length(cell));
	vec3 col = src;
	col = mix(col, col * 0.93, pip * paperness * 0.6 * params.grid);
	col += (hash(floor(px)) - 0.5) * 0.012 * paperness;

	float dx = min(px.x, res.x - px.x);
	float dy = min(px.y, res.y - px.y);
	float edge = min(dx, dy);

	float frame = 1.0 - smoothstep(9.0, 10.0, edge);
	col = mix(col, PAPER, frame);
	col = mix(col, HAIR, line(edge - 9.5, 0.2));

	float ticks = step(px.x, 9.0) * step(5.0, px.x) * line(mod(fromTop.y, 48.0) - 24.0, 0.3);
	col = mix(col, GRAPHITE, ticks);

	float marker = rect(fromTop, vec2(res.x * 0.62, 3.0), vec2(res.x * 0.62 + 9.0, 9.0));
	float pulse = 0.75 + 0.25 * sin(t * 2.0);
	col = mix(col, ORANGE, marker * pulse);

	float tab = rect(fromTop, vec2(res.x - 150.0, res.y - 8.0), vec2(res.x - 40.0, res.y - 3.0));
	col = mix(col, GRAPHITE, tab);
	float accent = rect(fromTop, vec2(res.x - 38.0, res.y - 8.0), vec2(res.x - 22.0, res.y - 3.0));
	col = mix(col, ORANGE, accent);

	float dashes = step(px.y, 7.0) * step(3.0, px.y) * step(0.5, fract(px.x / 10.0)) * step(res.x * 0.12, px.x) * step(px.x, res.x * 0.30);
	col = mix(col, HAIR, dashes);

	FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
