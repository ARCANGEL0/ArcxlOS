#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float intensity;
	float logo_scale;
	float pixels;
	float scan;
} params;

#pragma parameter intensity "Logo Strength" 0.16 0.0 1.0 0.01
#pragma parameter logo_scale "Logo Size" 0.34 0.05 1.0 0.01
#pragma parameter pixels "Pixel Grid" 72.0 16.0 192.0 4.0
#pragma parameter scan "Scanline Depth" 0.30 0.0 0.8 0.02
#define backbuffer accum1
#define blurbuffer blur2

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
{
	vTexCoord = TexCoord;
	gl_Position = MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D accum1;
layout(set = 0, binding = 4) uniform sampler2D blur2;
layout(set = 0, binding = 5) uniform sampler2D logotex;

#define ACC vec3(0.588, 0.129, 0.180)

void main()
{
	vec2 uv = vTexCoord;
	vec3 src = texture(Source, uv).rgb;
	vec3 acc = texture(accum1, uv).rgb;
	vec3 outc = mix(src, acc, 0.35);

	vec2 res = params.OutputSize.xy;
	vec2 luv = (uv - 0.5) * res;
	vec2 lsize = vec2(textureSize(logotex, 0)) * params.logo_scale * min(res.x, res.y) / max(textureSize(logotex, 0).x, 1.0);
	vec2 p = luv / lsize + 0.5;

	float pulse = 0.72 + 0.28 * sin(float(params.FrameCount) * 0.03);
	float a = 0.0;
	vec3 mark = ACC;
	if (p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0) {
		vec2 grid = vec2(params.pixels, params.pixels * 0.5);
		vec2 q = (floor(p * grid) + 0.5) / grid;
		vec4 t = texture(logotex, vec2(q.x, 1.0 - q.y));
		float scan = 1.0 - params.scan * step(0.5, fract(p.y * grid.y));
		a = t.a * params.intensity * pulse * scan;
		mark = mix(vec3(0.55, 0.10, 0.14), ACC, t.r) * scan;
	}
	outc = mix(outc, mark, clamp(a, 0.0, 1.0));
	FragColor = vec4(outc, 1.0);
}
