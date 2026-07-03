shader_type spatial;
// Renders objects without standard realistic lighting
render_mode diffuse_toon, specular_disabled;

// --- 1. COLOR & TEXTURE SETTINGS ---
uniform vec4 flat_color : source_color = vec4(1.0);
uniform bool use_texture = false;
// filter_nearest is CRITICAL for crisp pixel art textures
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D normal_texture : hint_normal, filter_nearest;
uniform sampler2D roughness_texture : hint_roughness_r, filter_nearest;

// --- 2. STEPPED LIGHTING SETTINGS ---
uniform int lighting_steps : hint_range(1, 8) = 3; 
uniform float lighting_wrap : hint_range(-2.0, 2.0) = 0.0;
uniform float lighting_steepness : hint_range(1.0, 8.0) = 1.0;

// --- 3. INNER EDGE / RIM HIGHLIGHT ---
uniform bool use_inner_edge = true;
uniform float inner_edge_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 inner_edge_color : source_color = vec4(1.0);

void fragment() {
    // Default to the flat color
    vec3 albedo_result = flat_color.rgb;
    float roughness_result = 1.0;

    // Override with textures if the boolean is checked
    if (use_texture) {
        vec4 tex_color = texture(albedo_texture, UV);
        albedo_result = tex_color.rgb;
        
        // Apply Normal and Roughness maps if provided
        NORMAL_MAP = texture(normal_texture, UV).rgb;
        roughness_result = texture(roughness_texture, UV).r;
    }

    ALBEDO = albedo_result;
    ROUGHNESS = roughness_result;
}

void light() {
    // --- Stepped Toon Lighting Logic ---
    float NdotL = dot(NORMAL, LIGHT);
    
    // Calculate diffuse with attenuation (shadows) and wrap
    float diffuse_amount = NdotL + (ATTENUATION - 1.0) + lighting_wrap;
    diffuse_amount *= lighting_steepness; 
    
    // Step the lighting to create hard, pixel-art style color bands
    float step_size = 1.0 / float(lighting_steps);
    float diffuse_stepped = clamp(diffuse_amount + mod(1.0 - diffuse_amount, step_size), 0.0, 1.0); 

    vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI; 
    diffuse *= diffuse_stepped; 
    DIFFUSE_LIGHT += diffuse;

    // --- Inner Edge (Rim) Logic ---
    if (use_inner_edge) {
        float NdotV = dot(NORMAL, VIEW); 
        float rim_light = pow(1.0 - NdotV, inner_edge_width); 
        DIFFUSE_LIGHT += rim_light * inner_edge_color.rgb * inner_edge_color.a * LIGHT_COLOR / PI; 
    }
}