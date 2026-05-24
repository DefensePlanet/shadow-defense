shader_type canvas_item;

uniform float threshold : hint_range(0.0, 0.3) = 0.08;
uniform float smoothness : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float brightness = max(tex.r, max(tex.g, tex.b));
    float alpha = smoothstep(threshold, threshold + smoothness, brightness);
    COLOR = vec4(tex.rgb, tex.a * alpha);
}
