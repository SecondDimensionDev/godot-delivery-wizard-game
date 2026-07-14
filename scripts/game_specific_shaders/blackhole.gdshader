shader_type spatial;
render_mode blend_add, cull_disabled, shadows_disabled;

// Texture uniforms
uniform sampler2D transparency_mask : source_color, hint_default_white;
uniform sampler2D emission_mask : source_color, hint_default_black;
uniform sampler2D portal_texture : source_color, hint_default_white;

// Portal properties
uniform float scale : hint_range(0.0, 1.0) = 0.5;
uniform float rotation_speed : hint_range(0.0, 10.0) = 0.2;
uniform float time_offset = 0.0;

// Material properties
uniform float emission_strength : hint_range(0.0, 16.0) = 2.0;

varying vec2 vertex_uv;

void vertex() {
    vertex_uv = UV;
}

// Portal UV calculation function
vec4 sample_portal_texture(vec2 uv, sampler2D tex, float time_val, float rot_speed, float scale_val) {
    vec2 centered_uv = uv - vec2(0.5);
    float dist = length(centered_uv);
    float base_angle = atan(centered_uv.y, centered_uv.x);

    float t = time_val + time_offset;

    float angle_cw = base_angle + t * rot_speed;
    float angle_ccw = base_angle - t * rot_speed;

    float norm_angle_cw = (angle_cw + 3.14159265) / (2.0 * 3.14159265);
    float norm_angle_ccw = (angle_ccw + 3.14159265) / (2.0 * 3.14159265);

    vec2 polar_uv_cw = vec2(norm_angle_cw, dist / scale_val);
    vec2 polar_uv_ccw = vec2(norm_angle_ccw, dist / scale_val);

    vec4 color_cw = texture(tex, polar_uv_cw);
    vec4 color_ccw = texture(tex, polar_uv_ccw);
    
    return mix(color_cw, color_ccw, 0.5);
}

void fragment() {
    // Sample transparency mask
    vec4 transparency_sample = texture(transparency_mask, vertex_uv);
    float alpha_mask = transparency_sample.a;
    
    // Portal texture sampling with rotation
    vec4 portal_sample = sample_portal_texture(vertex_uv, portal_texture, TIME, rotation_speed, scale);
    
    // Calculate distance from center for portal effects
    vec2 centered_uv = vertex_uv - vec2(0.5);
    float dist = length(centered_uv);
    
    // Use portal texture directly for color
    float grayscale = portal_sample.r;
    
    // Portal alpha calculations (simplified)
    float portal_alpha = smoothstep(scale, 0.0, dist);
    
    // Sample emission mask (preserving original blackhole functionality)
    vec4 emission_sample = texture(emission_mask, vertex_uv);
    vec3 emission_data = emission_sample.rgb;
    
    // Combine portal emission with emission mask
    vec3 final_emission = emission_data * grayscale * emission_strength;
    
    // Set material properties
    ALBEDO = vec3(0.0, 0.0, 0.0); // Keep black albedo for blackhole effect
    ALPHA = portal_alpha * alpha_mask;
    EMISSION = final_emission;
}