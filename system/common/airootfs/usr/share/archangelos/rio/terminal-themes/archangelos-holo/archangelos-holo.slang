#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float glow;
	float logoSize;
} params;

#pragma parameter glow "Phosphor Glow" 1.0 0.0 2.0 0.05
#pragma parameter logoSize "Logo Size" 1.0 0.5 2.0 0.05

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
layout(set = 0, binding = 5) uniform sampler2D logotex;

#define RED     vec3(1.000, 0.090, 0.200)
#define RED_HI  vec3(1.000, 0.420, 0.500)
#define RED_DIM vec3(0.360, 0.020, 0.060)
#define WHITE   vec3(1.000, 0.960, 0.970)
#define PLATE   vec3(0.012, 0.005, 0.008)
#define TINT    vec3(0.030, 0.006, 0.012)

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

vec4 logoAt(vec2 uv)
{
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
	return texture(logotex, vec2(uv.x, 1.0 - uv.y));
}

void main()
{
	float t = float(params.FrameCount) / 60.0;
	vec2 uv = vTexCoord;
	vec2 res = params.OutputSize.xy;
	vec2 px = uv * res;

	float dx = min(px.x, res.x - px.x);
	float dy = min(px.y, res.y - px.y);
	float edge = min(dx, dy);

	vec2 split = vec2(0.0009, 0.0);
	vec3 src = vec3(fetch(accum1, uv + split).r, fetch(accum1, uv).g, fetch(accum1, uv - split).b);
	vec3 bloom = fetch(blur2, uv);
	float ink = smoothstep(0.06, 0.30, luma(src));

	vec3 col = TINT + src * 1.18;
	col += bloom * bloom * 1.6 * params.glow;
	col += bloom * 0.35 * params.glow;
	col += RED * smoothstep(0.05, 0.4, luma(bloom)) * 0.06 * params.glow;

	float scan = 0.88 + 0.12 * sin(px.y * 3.14159265);
	col *= scan;

	float roll = fract(t * 0.07);
	float band = exp(-abs(uv.y - (1.0 - roll)) * 60.0);
	col += WHITE * band * 0.025;
	col *= 1.0 + band * 0.08;

	col *= 0.985 + 0.015 * sin(t * 47.0);
	col += (hash(floor(px) + fract(t)) - 0.5) * 0.012;

	vec2 vig = (uv - 0.5) * vec2(1.0, 1.1);
	col *= 1.0 - 0.32 * pow(clamp(length(vig) * 1.25, 0.0, 1.0), 3.0);

	float logoH = 70.0 * params.logoSize;
	vec2 logoDim = vec2(logoH * 1541.0 / 1211.0, logoH);
	vec2 logoMid = vec2(res.x - 34.0 - logoDim.x * 0.5, res.y - 30.0 - logoDim.y * 0.5);
	vec2 rel = px - logoMid;
	float logoMix = 0.0;

	if (abs(rel.x) < logoDim.x * 0.75 && abs(rel.y) < logoDim.y * 0.85)
	{
		float breathe = 0.5 + 0.5 * sin(t * 1.7);
		float cycle = fract(t / 9.0);
		float resolve = smoothstep(0.0, 0.16, cycle);
		float melt = smoothstep(0.93, 1.0, cycle);
		float coarse = max(1.0 - resolve, melt);
		float cell = floor(mix(3.0, 14.0, coarse));

		float glitch = step(0.965, fract(t * 0.13 + 0.4));
		float jitter = (hash(vec2(floor(rel.y / 3.0), floor(t * 20.0))) - 0.5) * glitch * 10.0;
		vec2 grid = rel + vec2(jitter, 0.0);
		vec2 block = floor(grid / cell);
		vec2 center = (block + 0.5) * cell;
		vec2 inCell = grid - block * cell;

		float reveal = step(hash(block + 3.1), mix(resolve, 1.0, 1.0 - melt) * (1.0 - melt * hash(block + 7.7)));
		vec2 luv = center / logoDim + 0.5;
		vec4 logo = logoAt(luv);
		float led = step(1.0, inCell.x) * step(1.0, inCell.y);

		float halo = 0.0;
		for (int i = 0; i < 8; i++)
		{
			float a = float(i) * 0.785398;
			halo += logoAt(rel / logoDim + 0.5 + vec2(cos(a), sin(a)) * 0.06).a;
		}
		halo /= 8.0;

		float redness = clamp((logo.r - logo.g) * 2.4, 0.0, 1.0);
		float twinkle = 0.7 + 0.3 * sin(t * 3.3 + hash(block) * 6.28);
		vec3 body = mix(WHITE, RED * 1.5 * twinkle, redness);

		float sweepPos = 1.2 - fract(t * 0.22) * 1.7;
		float sweep = exp(-abs(luv.y - sweepPos) * 30.0);
		float sparkle = step(0.985, hash(block + floor(t * 6.0))) * 0.6;

		vec3 logoCol = body * (0.82 + 0.18 * breathe) * mix(1.15, 0.7, 1.0 - led);
		logoCol += WHITE * (sweep * 0.8 + sparkle) * logo.a;
		logoCol += mix(WHITE, RED, 0.5) * coarse * 0.25;

		col += RED * halo * (0.18 + 0.32 * breathe);
		col += RED_HI * sweep * halo * 0.2;
		logoMix = logo.a * reveal * (0.95 - glitch * 0.2) * (1.0 - ink * 0.7);
		col = mix(col, logoCol, logoMix);
	}

	float frame = 1.0 - smoothstep(5.0, 6.0, edge);
	float hum = 0.9 + 0.1 * sin(t * 1.3) + 0.02 * sin(t * 37.0);
	float tube = line(edge - 5.5, 0.5);
	float core = line(edge - 5.5, 0.0);
	float halo = exp(-abs(edge - 5.5) * 0.35);

	vec3 frameCol = PLATE + RED * exp(-abs(5.5 - edge) * 0.7) * 0.35 * hum;
	col = mix(col, frameCol, frame);
	col += RED * halo * 0.22 * hum * (1.0 - frame * 0.4);
	col = mix(col, RED * 1.1 * hum, tube * 0.85);
	col = mix(col, RED_HI * 1.15, core * 0.5 * hum);
	col += RED * exp(-max(edge - 6.0, 0.0) * 0.05) * 0.04 * hum * (1.0 - frame);
	col = clamp(col, 0.0, 1.0);

	float alpha = 0.62 + 0.38 * clamp(ink * 2.0 + luma(bloom) * 1.5 + logoMix + frame + halo * 0.5, 0.0, 1.0);
	FragColor = vec4(col * alpha, alpha);
}
