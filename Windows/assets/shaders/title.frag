#version 120

uniform vec2  resolution;
uniform float time;
uniform vec3  tint;
uniform float tintMix;

mat2 rot2(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// ── Smooth-min for blending SDF primitives into bubbly blobs ──────────────────
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ── Capsule SDF (p: query, a/b: endpoints, r: radius) ─────────────────────────
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t) - r;
}

// ── Sphere SDF ────────────────────────────────────────────────────────────────
float sdSphere(vec3 p, vec3 c, float r) {
    return length(p - c) - r;
}

// ── The letter K as a bubbly SDF in 3-D ──────────────────────────────────────
//    Built from four smooth-blended capsules:
//      stem  : vertical bar on the left
//      arm_u : upper diagonal arm (top-right)
//      arm_l : lower diagonal arm (bottom-right)
//      joint : small blob at the intersection to keep things bubbly
//
//    All coordinates are in a [-1,1]^3 local space; the caller scales/rotates.
float sdK(vec3 p) {
    float r   = 0.22;   // tube radius — bigger = fatter, more blob-like
    float k   = 0.30;   // smoothing width — bigger = more melted together

    // Stem: straight vertical capsule on the left side
    float stem = sdCapsule(p,
    vec3(-0.35, -1.0, 0.0),
    vec3(-0.35,  1.0, 0.0),
    r);

    // Upper arm: from the mid-left junction up to the top-right
    float armU = sdCapsule(p,
    vec3(-0.35,  0.05, 0.0),
    vec3( 0.65,  1.0,  0.0),
    r);

    // Lower arm: from the mid-left junction down to the bottom-right
    float armL = sdCapsule(p,
    vec3(-0.35,  0.05, 0.0),
    vec3( 0.65, -1.0,  0.0),
    r);

    // Small blob at the junction so the three strokes melt together nicely
    float joint = sdSphere(p, vec3(-0.35, 0.05, 0.0), r * 1.15);

    float d = smin(stem,  armU,  k);
    d = smin(d,     armL,  k);
    d = smin(d,     joint, k);
    return d;
}

// ── Animating shell — wobble + slow rotation applied on top of K ──────────────
float sdf(vec3 p) {
    // Gentle slow rotation so the K gently tumbles
    p.xy *= rot2(time * 0.10);
    p.xz *= rot2(time * 0.07);

    // Organic surface noise so it stays "blobby" rather than hard-edged
    float noise = sin(p.x * 3.1 + time * 0.5) * cos(p.y * 2.7 - time * 0.4) * 0.055
    + sin(p.y * 4.3 + time * 0.6) * sin(p.z * 2.1 + time * 0.35) * 0.040
    + cos(p.z * 5.0 + p.x * 2.0  + time * 0.7) * 0.025;

    // Scale the K to roughly fill the view and offset it just left of center
    vec3 q = p * 1.30 - vec3(-0.05, 0.0, 0.0);

    return sdK(q) + noise;
}

void main() {
    // ── UV in [-aspect/2, aspect/2] x [-0.5, 0.5] ────────────────────────────
    vec2 uv = gl_FragCoord.xy / resolution.y
    - vec2(resolution.x / resolution.y * 0.5, 0.5);

    vec3 ro = vec3(0.0, 0.0, 4.2);
    vec3 rd = normalize(vec3(uv, -1.0));

    // ── Ray-march ─────────────────────────────────────────────────────────────
    vec3  col = vec3(0.0);
    float d   = 1.5;

    for (int i = 0; i < 9; i++) {
        vec3  p    = ro + rd * d;
        float rz   = sdf(p);

        // Cheap normal estimate for lighting
        vec3  poff = p + vec3(0.06);
        float f    = clamp((rz - sdf(poff)) * 0.7, -0.1, 1.0);

        // ── Natural deep-red palette (tintMix = 0) ────────────────────────────
        vec3 natBase   = vec3(0.16, 0.02, 0.02);
        vec3 natAccent = vec3(5.2,  1.1,  0.5);

        // ── Tinted palette (tintMix = 1) ──────────────────────────────────────
        vec3 tintBase   = natBase   * (tint * 3.2 + vec3(0.07));
        vec3 tintAccent = natAccent * (tint * 1.7 + vec3(0.10));

        vec3 base   = mix(natBase,   tintBase,   tintMix);
        vec3 accent = mix(natAccent, tintAccent, tintMix);

        vec3 lc = base + accent * f;
        col = col * lc + smoothstep(2.4, 0.0, rz) * 0.70 * lc;
        d  += min(rz, 0.8);
    }

    // ── Vignette ─────────────────────────────────────────────────────────────
    float vign = 1.0 - smoothstep(0.28, 1.15, length(uv * 0.92));
    col *= vign;

    // ── Gamma-ish tone ────────────────────────────────────────────────────────
    col = pow(max(col, 0.0), vec3(0.88, 1.0, 1.0));

    gl_FragColor = vec4(col, 1.0);
}
