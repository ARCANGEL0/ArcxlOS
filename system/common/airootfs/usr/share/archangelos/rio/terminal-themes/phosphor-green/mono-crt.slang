#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float tintR;
	float tintG;
	float tintB;
	float glow;
	float curve;
	float scan;
	float crush;
} params;

#pragma parameter tintR "Phosphor Red" 0.33 0.0 1.0 0.01
#pragma parameter tintG "Phosphor Green" 1.0 0.0 1.0 0.01
#pragma parameter tintB "Phosphor Blue" 0.50 0.0 1.0 0.01
#pragma parameter glow "Glow" 1.0 0.0 3.0 0.05
#pragma parameter curve "Tube Curve" 1.0 0.0 2.0 0.05
#pragma parameter scan "Scanlines" 1.0 0.0 1.5 0.05
#pragma parameter crush "Black Level" 0.03 0.0 0.3 0.01

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

#define INSET  14.0
#define RADIUS 26.0

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

vec2 bend(vec2 uv)
{
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + 0.04 * params.curve * dot(c.yx, c.yx);
	return c * 0.5 + 0.5;
}

float boxDist(vec2 p, vec2 size, float r)
{
	vec2 q = abs(p) - size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
	float t = float(params.FrameCount) / 60.0;
	vec2 res = params.OutputSize.xy;
	vec3 phos = vec3(params.tintR, params.tintG, params.tintB);
	vec3 hot = mix(phos, vec3(0.9, 1.0, 1.0), 0.35);

	vec2 glass = res - 2.0 * INSET;
	vec2 local = (vTexCoord * res - INSET) / glass;
	vec2 uv = bend(local);
	vec2 px = uv * res;

	float dist = boxDist((uv - 0.5) * glass, glass * 0.5, RADIUS);
	float screen = 1.0 - smoothstep(-1.5, 0.5, dist);

	float jitter = (hash(vec2(floor(t * 30.0), floor(px.y / 2.0))) - 0.5) * 0.0006 * step(0.985, hash(vec2(floor(t * 4.0), 1.0)));
	vec2 suv = uv + vec2(jitter, 0.0);

	float text = luma(fetch(accum1, suv));
	float ghost = luma(fetch(accum1, suv - vec2(0.0016, 0.0)));
	float bloom = luma(fetch(blur2, suv));

	float level = max(text - params.crush, 0.0) / (1.0 - params.crush);
	float halo = max(bloom - params.crush * 0.6, 0.0);

	vec3 col = phos * 0.006;
	col += phos * (level * 1.1 + ghost * 0.06);
	col += hot * pow(level, 3.0) * 0.25;
	col += phos * (halo * 0.9 + halo * halo * 1.0) * params.glow;

	float lines = 0.5 + 0.5 * sin(px.y * 3.14159265);
	col *= mix(1.0, 0.55 + 0.45 * pow(lines, 1.3), params.scan);
	float mask = mod(floor(px.x), 3.0);
	col *= mix(1.0, mask == 1.0 ? 1.0 : 0.88, params.scan);

	float roll = exp(-abs(uv.y - fract(t * 0.11)) * 18.0);
	col += phos * roll * 0.02;
	col *= 1.0 + roll * 0.08;

	col *= 0.97 + 0.03 * sin(t * 59.0) * sin(t * 7.3);
	col += phos * (hash(floor(px) + fract(t * 13.0)) - 0.5) * 0.035;

	vec2 v = uv - 0.5;
	col *= 1.0 - 0.6 * pow(clamp(length(v * vec2(1.0, 1.15)) * 1.3, 0.0, 1.0), 2.4);

	vec2 hl = (local - vec2(0.2, 0.84)) * vec2(1.0, 1.5);
	col += vec3(0.8) * exp(-dot(hl, hl) * 10.0) * 0.018;

	float lip = exp(-max(dist, 0.0) * 0.35) * (1.0 - screen);
	vec3 bezel = vec3(0.012) + phos * lip * 0.08;
	vec2 bp = vTexCoord * res;
	float outer = min(min(bp.x, res.x - bp.x), min(bp.y, res.y - bp.y));
	bezel += vec3(0.05) * (1.0 - smoothstep(0.0, 1.5, outer));
	bezel += vec3(0.025) * smoothstep(INSET * 0.5, INSET, outer) * (1.0 - smoothstep(INSET, INSET + 4.0, outer)) * (1.0 - screen);

	col = mix(bezel, clamp(col, 0.0, 1.0), screen);
	float lit = clamp(level + halo * 1.5, 0.0, 1.0);
	FragColor = vec4(col, mix(0.93, 1.0, lit));
}
