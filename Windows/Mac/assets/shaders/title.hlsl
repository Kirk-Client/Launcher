// title.hlsl  —  HLSL port of title.frag
// Ray-marched bubbly 'K' blob background shader for Kirk Launcher.
// ps_4_0 target (D3D11 feature level 10.0+).

cbuffer Constants : register(b0)
{
    float2 resolution;   // viewport width, height  (pixels)
    float  time;         // seconds since launch
    float  tintMix;      // 0 = natural deep-red, 1 = fully tinted
    float3 tint;         // RGB tint colour (0..1)
    float  _pad;
};

struct VSOut
{
    float4 pos : SV_POSITION;
    float2 uv  : TEXCOORD0;
};

// ─── Vertex shader: fullscreen triangle ───────────────────────────────────────
VSOut VS(uint id : SV_VertexID)
{
    // Two triangles from three vertices via SV_VertexID trick
    float2 uv  = float2((id << 1) & 2, id & 2);
    VSOut  o;
    o.pos      = float4(uv * float2(2, -2) + float2(-1, 1), 0, 1);
    o.uv       = uv;
    return o;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
float2x2 rot2(float a)
{
    float c = cos(a), s = sin(a);
    return float2x2(c, -s, s, c);
}

float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

float sdCapsule(float3 p, float3 a, float3 b, float r)
{
    float3 pa = p - a, ba = b - a;
    float  t  = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t) - r;
}

float sdSphere(float3 p, float3 c, float r)
{
    return length(p - c) - r;
}

// ─── Bubbly K SDF ─────────────────────────────────────────────────────────────
float sdK(float3 p)
{
    float r = 0.22;
    float k = 0.30;

    float stem  = sdCapsule(p, float3(-0.35, -1.0, 0.0), float3(-0.35,  1.0, 0.0), r);
    float armU  = sdCapsule(p, float3(-0.35,  0.05, 0.0), float3( 0.65,  1.0, 0.0), r);
    float armL  = sdCapsule(p, float3(-0.35,  0.05, 0.0), float3( 0.65, -1.0, 0.0), r);
    float joint = sdSphere(p, float3(-0.35, 0.05, 0.0), r * 1.15);

    float d = smin(stem,  armU,  k);
          d = smin(d,     armL,  k);
          d = smin(d,     joint, k);
    return d;
}

// ─── Animated SDF ─────────────────────────────────────────────────────────────
float sdf(float3 p)
{
    p.xy = mul(rot2(time * 0.10), p.xy);
    p.xz = mul(rot2(time * 0.07), p.xz);

    float noise = sin(p.x * 3.1 + time * 0.5) * cos(p.y * 2.7 - time * 0.4) * 0.055
                + sin(p.y * 4.3 + time * 0.6) * sin(p.z * 2.1 + time * 0.35) * 0.040
                + cos(p.z * 5.0 + p.x * 2.0  + time * 0.7) * 0.025;

    float3 q = p * 1.30 - float3(-0.05, 0.0, 0.0);
    return sdK(q) + noise;
}

// ─── Pixel shader ─────────────────────────────────────────────────────────────
float4 PS(VSOut input) : SV_TARGET
{
    // UV in [-aspect/2, aspect/2] x [-0.5, 0.5]  (same as GLSL version)
    float2 uv = input.pos.xy / resolution.y
              - float2(resolution.x / resolution.y * 0.5, 0.5);

    float3 ro = float3(0.0, 0.0, 4.2);
    float3 rd = normalize(float3(uv, -1.0));

    float3 col = float3(0.0, 0.0, 0.0);
    float  d   = 1.5;

    [unroll(9)]
    for (int i = 0; i < 9; i++)
    {
        float3 p   = ro + rd * d;
        float  rz  = sdf(p);

        float3 poff = p + float3(0.06, 0.06, 0.06);
        float  f    = clamp((rz - sdf(poff)) * 0.7, -0.1, 1.0);

        // Natural deep-red palette
        float3 natBase   = float3(0.16, 0.02, 0.02);
        float3 natAccent = float3(5.2,  1.1,  0.5);

        // Tinted palette
        float3 tintBase   = natBase   * (tint * 3.2 + float3(0.07, 0.07, 0.07));
        float3 tintAccent = natAccent * (tint * 1.7 + float3(0.10, 0.10, 0.10));

        float3 base   = lerp(natBase,   tintBase,   tintMix);
        float3 accent = lerp(natAccent, tintAccent, tintMix);

        float3 lc = base + accent * f;
        col = col * lc + smoothstep(2.4, 0.0, rz) * 0.70 * lc;
        d  += min(rz, 0.8);
    }

    // Stronger vignette — darkens the edges so the frosted panels read cleanly.
    float vign = 1.0 - smoothstep(0.16, 1.05, length(uv * 0.96));
    col *= vign;

    // Calm the overall intensity so the background is ambient, not busy.
    col *= 0.62;

    // Gamma-ish tone
    col = pow(max(col, 0.0), float3(0.88, 1.0, 1.0));

    return float4(col, 1.0);
}
