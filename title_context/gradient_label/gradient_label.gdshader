shader_type canvas_item;

uniform sampler2D gradient_texture : source_color, filter_linear;

// Set these from script: the label's global position.x and size.x in pixels
uniform float label_global_x = 0.0;
uniform float label_width = 100.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // SCREEN_UV is 0-1 across the viewport; convert to pixels
    float screen_pixel_x = SCREEN_UV.x * (1.0 / SCREEN_PIXEL_SIZE.x);

    float t = clamp((screen_pixel_x - label_global_x) / max(label_width, 0.0001), 0.0, 1.0);

    vec4 grad_color = texture(gradient_texture, vec2(t, 0.5));

    COLOR = vec4(grad_color.rgb, tex_color.a * grad_color.a * COLOR.a);
}