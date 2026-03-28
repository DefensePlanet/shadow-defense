shader_type canvas_item;
// Colorblind Correction Shader — Enhancement #16 (Accessibility)
// Applied via AccessibilityManager as a full-screen post-process.
// Supports: Protanopia, Deuteranopia, Tritanopia correction matrices.

uniform mat3 correction_matrix = mat3(
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 corrected = correction_matrix * tex_color.rgb;
	COLOR = vec4(corrected, tex_color.a);
}
