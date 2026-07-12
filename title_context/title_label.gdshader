shader_type canvas_item;

uniform vec4 color_left : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform vec4 color_right : source_color = vec4(1.0, 0.2, 0.9, 1.0);
uniform float glow_boost : hint_range(1.0, 8.0) = 3.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    vec4 grad_color = mix(color_left, color_right, UV.x);
    vec3 hdr_color = grad_color.rgb * glow_boost;

    COLOR = vec4(hdr_color, tex.a);
}