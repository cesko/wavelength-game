shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.0, 1.0, 1.0, 1.0); // cyan
uniform vec4 color_b : source_color = vec4(1.0, 0.0, 1.0, 1.0); // magenta
uniform float border_width : hint_range(0.001, 0.3) = 0.04;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;
uniform float glow_strength : hint_range(0.0, 8.0) = 2.0;
uniform float glow_size : hint_range(0.0, 0.5) = 0.15;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.15; // interior tint
uniform float brightness_mult : hint_range(1.0, 5.0) = 1.5; // for HDR bloom

// Signed distance function for rounded box, in [-1,1] space
float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // remap to -1..1
    vec2 half_size = vec2(1.0) - border_width; // keep border inside bounds
    float radius = corner_radius;

    float dist = rounded_box_sdf(uv, half_size, radius);

    // Border line (ring around dist == 0)
    float border_mask = 1.0 - smoothstep(0.0, border_width, abs(dist));

    // Soft outer glow, fades out over glow_size
    float glow_mask = 1.0 - smoothstep(0.0, glow_size, max(dist, 0.0));
    glow_mask = pow(glow_mask, 2.0); // sharper falloff

    // Interior fill mask (dist < 0 means inside shape)
    float inside_mask = 1.0 - smoothstep(-0.02, 0.0, dist);

    vec4 grad_color = mix(color_a, color_b, UV.x);

    vec4 border_color = grad_color * brightness_mult;
    vec4 glow_color = grad_color * glow_strength * glow_mask;
    vec4 fill_color = grad_color * fill_alpha * inside_mask;

    vec3 final_rgb = border_color.rgb * border_mask
                    + glow_color.rgb * (1.0 - border_mask)
                    + fill_color.rgb * (1.0 - border_mask) * (1.0 - glow_mask);

    float final_alpha = max(border_mask, max(glow_mask, fill_color.a));

    COLOR = vec4(final_rgb, final_alpha);
}