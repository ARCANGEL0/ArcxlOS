#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	uint FrameCount;
	float inset;
	float shadow;
} params;

#pragma parameter inset "Plate Inset" 1.0 0.0 2.0 0.05
#pragma parameter shadow "Text Shadow" 1.0 0.0 2.0 0.05
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

vec3 fetch( sampler2D samp, vec2 tc )
    {
    return texture( samp, vec2( tc.x, 1.0 - tc.y ) ).rgb;
    }
float luma( vec3 c )
    {
    return dot( c, vec3( 0.299, 0.587, 0.114 ) );
    }
float rand( vec2 co )
    {
    return fract( sin( dot( co.xy, vec2( 12.9898, 78.233 ) ) ) * 43758.5453 );
    }
float band( float x, float a, float b )
    {
    return smoothstep( a - 0.75, a + 0.75, x ) * ( 1.0 - smoothstep( b - 0.75, b + 0.75, x ) );
    }
float linemark( float x, float w )
    {
    return 1.0 - smoothstep( w, w + 1.0, abs( x ) );
    }
float hexdist( vec2 p )
    {
    p = abs( p );
    return max( p.x * 0.86602540378 + p.y * 0.5, p.y );
    }
float ring( vec2 p, float r, float w )
    {
    return 1.0 - smoothstep( w, w + 1.6, abs( hexdist( p ) - r ) );
    }
float ringc( vec2 p, float r, float w )
    {
    return 1.0 - smoothstep( w, w + 1.6, abs( length( p ) - r ) );
    }

#define PLATE_HI  vec3( 1.000, 1.000, 1.000 )
#define BEVEL_C   vec3( 0.520, 0.480, 0.505 )
#define STEEL     vec3( 0.557, 0.451, 0.456 )
#define IRON      vec3( 0.333, 0.243, 0.249 )
#define GRAPHITE  vec3( 0.022, 0.014, 0.018 )
#define CRIMSON   vec3( 0.588, 0.129, 0.180 )
#define ICE_GLOW  vec3( 0.038, 0.012, 0.016 )
#define GLASS     vec3( 0.072, 0.043, 0.048 )
#define FROST     vec3( 0.980, 0.858, 0.866 )
#define PHOS      vec3( 0.707, 0.066, 0.130 )
#define PHOS_HI   vec3( 0.960, 0.360, 0.470 )

#define SHELL_W     2.6
#define BEVEL_W    10.0
#define RAIL_W     12.0
#define BEZEL_W    14.0
#define CORNER_SZ  24.0
#define BRACE_LEN  84.0
#define BOLT_D      9.8

void main()
{
    float t   = float( params.FrameCount ) * 0.016;
    vec2  uv  = vTexCoord.xy;
    vec2  res = params.OutputSize.xy;
    vec2  px  = uv * res;

    vec3  src  = fetch( backbuffer, uv );
    float slum = luma( src );
    float ink  = smoothstep( 0.105, 0.335, slum );

    float dx = min( px.x, res.x - px.x );
    float dy = min( px.y, res.y - px.y );
    float d  = min( dx, dy );

    float topness = uv.y;
    float depth   = mix( 0.86, 1.16, smoothstep( 0.0, 1.0, topness ) );
    float pane    = 1.0 + 0.06 * sin( 6.28318530718 * uv.y * 1.7 + 0.6 );

    float sunk = ( 1.0 - smoothstep( BEZEL_W, BEZEL_W + 24.0, d ) ) * 0.14 * params.inset;
    float vig  = 1.0 - 0.34 * ( 1.0 - smoothstep( 0.0, 0.36,
                 d * 2.0 / max( min( res.x, res.y ), 1.0 ) ) );

    float diag  = ( px.x * 0.68 + ( res.y - px.y ) * 0.74 ) / max( res.x, 1.0 );
    float sheen = pow( clamp( 0.5 + 0.5 * sin( diag * 4.1 - 0.6 ), 0.0, 1.0 ), 7.0 ) * 0.105
                + pow( clamp( 0.5 + 0.5 * sin( diag * 4.1 + 2.1 ), 0.0, 1.0 ), 9.0 ) * 0.062;

    vec2  lp   = ( px - vec2( res.x * 0.26, res.y * 0.88 ) ) / max( res.y, 1.0 );
    float lamp = exp( -dot( lp, lp ) * 3.2 ) * 0.070;

    float pipe = ( 1.0 - smoothstep( BEZEL_W, BEZEL_W + 66.0, d ) ) * 0.086
               + ( 1.0 - smoothstep( BEZEL_W, BEZEL_W + 9.0, d ) ) * 0.052;

    float sweep = ( 1.0 - topness ) - fract( t * 0.42 );
    float scan  = linemark( sweep * res.y, 0.8 ) * 0.050
                + exp( -max( -sweep, 0.0 ) * 46.0 ) * 0.016;

    float grain  = ( rand( floor( px ) ) - 0.5 ) * 0.019;
    float brush  = ( rand( vec2( 7.0, floor( px.y ) ) ) - 0.5 ) * 0.011
                 + ( rand( vec2( 3.0, floor( px.y * 0.25 ) ) ) - 0.5 ) * 0.008;
    float fleck  = step( 0.9972, rand( floor( px * 0.5 ) ) ) * 0.13;

    vec3  blr = fetch( blurbuffer, uv + vec2( -0.0013, 0.0017 ) );
    float mat = smoothstep( 0.088, 0.420, luma( blr ) );

    vec2  mc   = px - vec2( res.x * 0.820, res.y * 0.50 );
    float mrad = min( res.x, res.y ) * 0.185;
    vec2  tl   = vec2( textureSize( logotex, 0 ) );
    vec2  lsize = tl * 0.34 * min( res.x, res.y ) / max( tl.x, 1.0 );
    vec2  luv2  = mc / lsize + 0.5;
    float pulse = 0.72 + 0.28 * sin( float( params.FrameCount ) * 0.03 );
    float lflick = 0.90 + 0.10 * sin( float( params.FrameCount ) * 0.61 + sin( float( params.FrameCount ) * 0.17 ) * 2.0 );
    float helix = 0.0;
    float lglow = 0.0;
    vec3  logoCol = PHOS;
    if ( luv2.x >= -0.16 && luv2.x <= 1.16 && luv2.y >= -0.16 && luv2.y <= 1.16 ) {
        vec2 lc = clamp( luv2, 0.001, 0.999 );
        vec4 tsoft = texture( logotex, vec2( lc.x, 1.0 - lc.y ) );
        vec2 lout = max( abs( luv2 - 0.5 ) - 0.5, 0.0 );
        float lfall = exp( -length( lout ) * 14.0 );
        lglow = tsoft.a * smoothstep( 0.04, 0.90, tsoft.r ) * lfall;
        if ( luv2.x >= 0.0 && luv2.x <= 1.0 && luv2.y >= 0.0 && luv2.y <= 1.0 ) {
            vec2 grid = vec2( 72.0, 36.0 );
            vec2 q = ( floor( luv2 * grid ) + 0.5 ) / grid;
            vec4 tlogo = texture( logotex, vec2( q.x, 1.0 - q.y ) );
            float scanl = 1.0 - 0.26 * step( 0.5, fract( luv2.y * grid.y ) );
            helix = tlogo.a * pulse * scanl;
            logoCol = ( mix( PHOS, PHOS_HI, tlogo.r ) + vec3( 1.0, 0.94, 0.97 ) * pow( tlogo.r, 2.4 ) * 1.05 ) * scanl;
        }
    }
    helix = clamp( helix, 0.0, 1.0 ) * ( 1.0 - step( d, 44.0 ) );
    lglow = clamp( lglow * lflick, 0.0, 1.0 ) * ( 1.0 - step( d, 44.0 ) );

    float bmk = linemark( dx - 46.0, 0.7 ) * step( 46.0, dy ) * ( 1.0 - smoothstep( 78.0, 80.0, dy ) )
              + linemark( dy - 46.0, 0.7 ) * step( 46.0, dx ) * ( 1.0 - smoothstep( 78.0, 80.0, dx ) );
    bmk = clamp( bmk, 0.0, 1.0 );

    float bl = smoothstep( 0.10, 0.78, luma( blr ) );
    vec3  crt = src * vec3( 1.05, 0.62, 0.66 ) + blr * PHOS * ( 0.40 + bl * 0.80 );
    crt += PHOS * mat * 0.60 * params.shadow;
      crt *= 1.0 + 0.16 * mat;
    crt += PHOS_HI * ink * 0.18;
    crt += PHOS * lglow * 0.95 + PHOS_HI * lglow * 0.50;
    crt += PHOS * helix * 0.55 + PHOS_HI * helix * 0.35;
    crt = mix( crt, logoCol, clamp( helix * 0.95, 0.0, 1.0 ) );
    crt += PHOS * bmk * 0.12;

    float holo = 0.94 + 0.06 * sin( uv.y * 8.0 - t * 2.2 );
    crt *= mix( 1.0, holo, 0.12 );
    float scanl2 = 1.0 - 0.13 * pow( 0.5 + 0.5 * sin( px.y * 2.0943951 ), 1.5 );
    crt *= scanl2 * ( 1.0 + scan );

     float aR = luma( fetch( backbuffer, uv + vec2( 0.0020, 0.0 ) ) );
    float aB = luma( fetch( backbuffer, uv - vec2( 0.0020, 0.0 ) ) );
    crt.r += aR * 0.12;
    crt.b += aB * 0.10;

    float flick = 0.92 + 0.08 * rand( vec2( float( params.FrameCount ), 0.0 ) );
    crt *= flick;

    crt += vec3( ( rand( floor( px ) ) - 0.5 ) * 0.010 );

    vec2  vp = ( uv - 0.5 ) * vec2( 1.05, 1.0 );
    crt *= 1.0 - 0.26 * pow( clamp( length( vp ) * 1.30, 0.0, 1.0 ), 2.8 );

    crt += PHOS_HI * pow( clamp( uv.y, 0.0, 1.0 ), 8.0 ) * 0.05;
    crt = clamp( crt, vec3( 0.0 ), vec3( 1.0 ) );

    vec3 col = crt;

    float plate = 1.0 - smoothstep( BEZEL_W, BEZEL_W + 1.6, d );
    float lip   = band( d, BEZEL_W - 1.5, BEZEL_W - 0.2 );
    float rim   = band( d, SHELL_W - 2.6, SHELL_W - 1.2 );

    col = mix( col, GRAPHITE, plate );
    col = mix( col, BEVEL_C,  lip * 0.80 );
    col = mix( col, PHOS,     rim * 0.40 );
    col += PHOS * exp( -d * 0.040 ) * 0.09 * ( 1.0 - plate );

    float chrome = clamp( plate + lip + rim * 0.6 + helix * 0.16 + lglow * 0.10 + bmk * 0.20, 0.0, 1.0 );

    col = clamp( col, vec3( 0.0 ), vec3( 1.0 ) );

    const float PLATE_ALPHA = 0.40;
    float alpha = PLATE_ALPHA + ( 1.0 - PLATE_ALPHA )
                * clamp( ink * 2.4 + mat * 0.95 + chrome + sunk * 1.6
                       + pipe * 0.9 + fleck * 1.6 + helix * 1.2 + lglow * 0.9, 0.0, 1.0 );
    alpha = clamp( alpha, 0.0, 1.0 );

    FragColor = vec4( col * alpha, alpha );
}
