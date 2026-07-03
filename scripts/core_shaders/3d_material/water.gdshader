shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D noise_texture;
uniform sampler2D foam_texture;
uniform sampler2D depth_texture : hint_depth_texture;
uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.4, 1.0);
uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wave_strength = 0.6;
uniform vec2 wave_speed = vec2(0.05, 0.05);
uniform float water_transparency = 0.8;
uniform float water_roughness = 0.4;
uniform float foam_distance = -0.25;
uniform float surface_noise_cutoff = 1.0;
uniform float normal_strength = 0.5;
uniform float water_depth_fade = 0.5;


vec3 get_noise(vec2 uv, float time) {
    vec4 noise1 = texture(noise_texture, uv + time * wave_speed);
    vec4 noise2 = texture(noise_texture, (uv - time * wave_speed) * 4.0);
    return noise1.rgb * noise2.rgb;
}

void vertex() {
    vec3 noise = get_noise(UV, TIME);
    VERTEX += NORMAL * wave_strength * noise;
}

void fragment() {
    vec3 noise = get_noise(UV, TIME);
    float enhanced_noise = pow(noise.x, 1.25);
    
    float depth_sample = texture(depth_texture, SCREEN_UV).r;
    vec4 depth_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_sample, 1.0);
    depth_pos.xyz /= depth_pos.w;
    float depth_difference = depth_pos.z - VERTEX.z;
    
    // Depth-based gradient calculation
    float depth_fade = clamp(1.0 - smoothstep(depth_pos.z + water_depth_fade, depth_pos.z, VERTEX.z), 0.0, 1.0);
    
    float foam_depth_difference01 = clamp(depth_difference / foam_distance, 0.0, 1.0);
    float surface_noise_cutoff_modulated = foam_depth_difference01 * surface_noise_cutoff;
    
    float surface_noise_sample = texture(foam_texture, UV + TIME * (wave_speed/-2.0)).r;
    float surface_noise = surface_noise_sample > surface_noise_cutoff_modulated ? 1.0 : 0.0;
    
    float foam_mask = surface_noise;
    
    vec3 ripple_effect = mix(water_color.rgb, ripple_color.rgb, enhanced_noise * 0.6);
    // Simple depth gradient: shallow = water_color, deep = darker
    vec3 darker_water = water_color.rgb * 0.3; // Darker version for deep areas
    vec3 depth_gradient_color = mix(darker_water, ripple_effect, depth_fade);
    vec3 final_color = mix(depth_gradient_color, ripple_color.rgb, foam_mask);
    
    vec3 normal_map = normalize(vec3(
        (noise.x - 0.5) * 2.0,
        (noise.y - 0.5) * 2.0,
        1.0
    ));
    
    ALBEDO = final_color;
    NORMAL = mix(vec3(0.0, 0.0, 1.0), normal_map, normal_strength);
    ALPHA = water_transparency;
    ROUGHNESS = water_roughness;
}