shader_type canvas_item;
// Bottom-to-top gradient overlay for art-backed cards
// Makes text readable over any art background
uniform float gradient_start : hint_range(0.0, 1.0) = 0.25;
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.70;
uniform vec4 tint_color : source_color = vec4(0.02, 0.01, 0.04, 1.0);

void fragment() {
	float alpha = smoothstep(gradient_start, 1.0, UV.y) * gradient_strength;
	COLOR = vec4(tint_color.rgb, alpha);
}
