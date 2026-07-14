shader_type spatial; 
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float viewmodel_fov : hint_range(10.0, 120.0) = 50.0;

// Base properties
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;

// Textures
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D metallic_texture : hint_default_black;
uniform sampler2D roughness_texture : hint_default_white;
uniform sampler2D normal_texture : hint_normal;

void vertex() {
    float fov_rad = viewmodel_fov * PI / 180.0;
    float onetanfov = 1.0 / tan(0.5 * fov_rad);
    float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;

    PROJECTION_MATRIX[1][1] = -onetanfov;
    PROJECTION_MATRIX[0][0] = onetanfov / aspect;

    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX.xyz, 1.0);
    POSITION.z = mix(POSITION.z, POSITION.w, 0.79);
}

void fragment() {
    // Multiply texture by the base color
    vec4 albedo_tex = texture(albedo_texture, UV);
    ALBEDO = albedo_color.rgb * albedo_tex.rgb;
    
    // Apply scalars and textures for PBR
    METALLIC = metallic * texture(metallic_texture, UV).r;
    ROUGHNESS = roughness * texture(roughness_texture, UV).r;
    NORMAL_MAP = texture(normal_texture, UV).rgb;
}
//shader_type spatial;
//render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
//
//uniform float viewmodel_fov : hint_range(10.0, 120.0) = 50.0;
//uniform sampler2D albedo_texture : source_color;
//
//void vertex() {
	//float fov_rad = viewmodel_fov * PI / 180.0;
	//float onetanfov = 1.0 / tan(0.5 * fov_rad);
	//float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	//
	//// 1. RESTORE THE NEGATIVE SIGN (Fixes the upside-down gun)
	//PROJECTION_MATRIX[1][1] = -onetanfov;
	//PROJECTION_MATRIX[0][0] = onetanfov / aspect;
	//
	//// Calculate the default position
	//POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX.xyz, 1.0);
	//
	//// 2. THE REVERSE-Z DEPTH HACK (Fixes the giant gun in the sky)
	//// In Godot 4, POSITION.w represents the near clipping plane.
	//// By mixing our depth toward POSITION.w, we glue the gun directly to the camera lens.
	//POSITION.z = mix(POSITION.z, POSITION.w, 0.79); 
//}
//
//void fragment() {
	//// Apply the base color/texture
	//vec4 albedo_tex = texture(albedo_texture, UV);
	//ALBEDO = albedo_tex.rgb;
//}