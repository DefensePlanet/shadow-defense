shader_type canvas_item;

uniform float time_scale : hint_range(0.0, 2.0) = 0.3;
uniform float ink_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float drip_speed : hint_range(0.0, 3.0) = 0.5;
uniform float edge_tear : hint_range(0.0, 0.3) = 0.08;
uniform vec4 ink_color : source_color = vec4(0.05, 0.02, 0.10, 1.0);

// Noise function for organic ink shapes
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float t = TIME * time_scale;
    vec2 uv = UV;

    // Edge tear — torn page effect on borders
    float edge_left = smoothstep(0.0, edge_tear, uv.x + (noise(vec2(uv.y * 8.0, t * 0.2)) - 0.5) * 0.03);
    float edge_right = smoothstep(0.0, edge_tear, 1.0 - uv.x + (noise(vec2(uv.y * 8.0 + 100.0, t * 0.2)) - 0.5) * 0.03);
    float edge_top = smoothstep(0.0, edge_tear * 0.5, uv.y + (noise(vec2(uv.x * 10.0, t * 0.15)) - 0.5) * 0.02);
    float edge_bottom = smoothstep(0.0, edge_tear, 1.0 - uv.y + (noise(vec2(uv.x * 10.0 + 50.0, t * 0.15)) - 0.5) * 0.02);
    float edges = 1.0 - edge_left * edge_right * edge_top * edge_bottom;

    // Ink drips — vertical streaks that slowly descend
    float drip1 = smoothstep(0.02, 0.0, abs(uv.x - 0.12 - noise(vec2(0.0, t * 0.1)) * 0.05));
    float drip1_y = smoothstep(0.0, 0.4 + sin(t * drip_speed) * 0.15, uv.y);
    drip1 *= drip1_y * 0.6;

    float drip2 = smoothstep(0.015, 0.0, abs(uv.x - 0.88 + noise(vec2(5.0, t * 0.12)) * 0.04));
    float drip2_y = smoothstep(0.0, 0.55 + sin(t * drip_speed * 0.8 + 1.5) * 0.2, uv.y);
    drip2 *= drip2_y * 0.5;

    float drip3 = smoothstep(0.01, 0.0, abs(uv.x - 0.5 - noise(vec2(10.0, t * 0.08)) * 0.06));
    float drip3_y = smoothstep(0.0, 0.3 + sin(t * drip_speed * 1.2 + 3.0) * 0.1, uv.y);
    drip3 *= drip3_y * 0.3;

    // Ink splotches — fbm noise for organic blob shapes
    float splotch = fbm(uv * 6.0 + vec2(t * 0.05, t * 0.03));
    splotch = smoothstep(0.55, 0.65, splotch) * 0.25;

    // Corner ink pools
    float corner_bl = 1.0 - smoothstep(0.0, 0.25, length(uv - vec2(0.0, 1.0)));
    float corner_br = 1.0 - smoothstep(0.0, 0.2, length(uv - vec2(1.0, 1.0)));
    float corners = (corner_bl + corner_br) * 0.3;

    // Combine all ink effects
    float ink = (edges + drip1 + drip2 + drip3 + splotch + corners) * ink_intensity;
    ink = clamp(ink, 0.0, 0.6);

    // Slight purple tint in ink
    vec3 final_color = ink_color.rgb;
    COLOR = vec4(final_color, ink);
}
