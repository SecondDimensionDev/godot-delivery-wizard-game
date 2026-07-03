shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D noise_texture;
uniform float distortion_intensity : hint_range(0.0, 0.5) = 0.01;
uniform vec2 scroll_speed = vec2(0.1, 0.1);

vec2 get_noise_distortion(vec2 uv, float time) {
    
    vec2 noise_uv1 = uv + time * scroll_speed;
    vec2 noise_uv2 = uv - time * scroll_speed * 0.7;
    
    vec4 noise1 = texture(noise_texture, noise_uv1);
    vec4 noise2 = texture(noise_texture, noise_uv2);
    
    vec2 distortion = vec2(
        noise1.r - 0.5,
        noise2.g - 0.5
    );
    
    return distortion;
}

void fragment() {
    vec2 base_uv = SCREEN_UV;
    float time = TIME;
    
    vec2 noise_distortion = get_noise_distortion(UV, time);
    
    vec2 distorted_uv = base_uv + noise_distortion * distortion_intensity;
    
    distorted_uv = clamp(distorted_uv, vec2(0.0), vec2(1.0));
    
    vec4 distorted_color = texture(screen_texture, distorted_uv);

    float distortion_amount = length(noise_distortion);
    vec3 tint = mix(vec3(1.0), vec3(0.9, 1.0, 1.1), distortion_amount * 0.5);
    
    ALBEDO = distorted_color.rgb * tint;
    ALPHA = distorted_color.a;
}
