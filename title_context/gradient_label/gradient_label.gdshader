shader_type canvas_item;

uniform sampler2D gradient_texture : source_color, filter_linear;

// Local-space width of this Label control, in pixels.
uniform float label_width = 100.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    float t = clamp(VERTEX.x / max(label_width, 0.0001), 0.0, 1.0);

    vec4 grad_color = texture(gradient_texture, vec2(t, 0.5));

    COLOR = vec4(grad_color.rgb, tex_color.a * grad_color.a * COLOR.a);
}