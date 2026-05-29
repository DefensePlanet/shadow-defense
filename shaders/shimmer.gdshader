shader_type canvas_item;
// Shimmer scan line effect for premium/reward cards
uniform float speed : hint_range(0.1, 3.0) = 0.8;
uniform float width : hint_range(0.02, 0.3) = 0.12;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float time_offset = mod(TIME * speed, 1.0 + width * 2.0) - width;
	float shimmer = smoothstep(time_offset - width, time_offset, UV.x)
	              * smoothstep(time_offset + width, time_offset, UV.x);
	vec4 base = texture(TEXTURE, UV);
	COLOR = base + vec4(1.0, 0.95, 0.80, 0.0) * shimmer * intensity * base.a;
}
