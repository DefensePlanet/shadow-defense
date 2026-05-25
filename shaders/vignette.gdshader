shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float vig = smoothstep(1.0 - softness, 1.0, dist);
    COLOR = vec4(0.0, 0.0, 0.0, vig * intensity);
}
