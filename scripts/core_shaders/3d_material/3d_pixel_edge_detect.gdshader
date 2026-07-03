shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

// Combined and Optimized Edge Detection Shader (with Pixelation)

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

group_uniforms Edge_Toggles;
uniform bool shadows_enabled = true;
uniform bool highlights_enabled = true;
uniform bool use_roughness_mask = false; 

group_uniforms Edge_Controls;
uniform float outline_thickness : hint_range(0.0, 5.0, 0.1) = 1.0; 
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform vec3 highlight_color : source_color = vec3(1.0);
uniform vec3 shadow_color : source_color = vec3(0.0);

group_uniforms Pixelation;
uniform bool use_pixelation = false;
// Controls how large the "pixels" are (e.g., 4.0 means 4x4 screen pixels become 1 chunky pixel)
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;

float getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix, float mask){
	float raw_depth = texture(depth_texture, screen_uv)[0] * mask;
	vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);	
	view_space.xyz /= view_space.w;
	return -view_space.z;
}

float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal, float depth_diff){
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	float depthIndicator = clamp(sign(depth_diff * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(baseNormal, newNormal)) * depthIndicator * normalIndicator;
}

void vertex(){
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 e = vec2(outline_thickness / VIEWPORT_SIZE.xy);
	
	float outline_mask = 1.0;
	if (use_roughness_mask) {
		outline_mask = ceil(texture(NORMAL_TEXTURE, SCREEN_UV).a); 
	}
	
	// --- OUTLINE DETECTION (Uses smooth, high-res UVs to prevent jitter) ---
	float depth_diff = 0.0;
	float neg_depth_diff = 0.5;
	
	if (shadows_enabled) {
		float depth = getDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outline_mask);
		float du = getDepth(SCREEN_UV+vec2(0., -1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outline_mask);
		float dr = getDepth(SCREEN_UV+vec2(1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outline_mask);
		float dd = getDepth(SCREEN_UV+vec2(0., 1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outline_mask);
		float dl = getDepth(SCREEN_UV+vec2(-1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outline_mask);
		
		depth_diff += clamp(du - depth, 0., 1.);
		depth_diff += clamp(dd - depth, 0., 1.);
		depth_diff += clamp(dr - depth, 0., 1.);
		depth_diff += clamp(dl - depth, 0., 1.);
		
		neg_depth_diff += depth - du;
		neg_depth_diff += depth - dd;
		neg_depth_diff += depth - dr;
		neg_depth_diff += depth - dl;
		neg_depth_diff = clamp(neg_depth_diff, 0., 1.);
		neg_depth_diff = clamp(smoothstep(0.5, 0.5, neg_depth_diff)*10., 0., 1.);
		
		depth_diff = smoothstep(0.2, 0.3, depth_diff);
	}
	
	float normal_diff = 0.;
	
	if (highlights_enabled) {
		vec3 normal = texture(NORMAL_TEXTURE, SCREEN_UV).rgb * 2.0 - 1.0 * outline_mask;
		vec3 nu = texture(NORMAL_TEXTURE, SCREEN_UV+vec2(0., -1.)*e).rgb * 2.0 - 1.0 * outline_mask;
		vec3 nr = texture(NORMAL_TEXTURE, SCREEN_UV+vec2(1., 0.)*e).rgb * 2.0 - 1.0 * outline_mask;
		vec3 nd = texture(NORMAL_TEXTURE, SCREEN_UV+vec2(0., 1.)*e).rgb * 2.0 - 1.0 * outline_mask;
		vec3 nl = texture(NORMAL_TEXTURE, SCREEN_UV+vec2(-1., 0.)*e).rgb * 2.0 - 1.0 * outline_mask;
		
		vec3 normal_edge_bias = vec3(1., 1., 1.);
		normal_diff += normalIndicator(normal_edge_bias, normal, nu, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nr, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nd, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nl, depth_diff);
		
		normal_diff = smoothstep(0.2, 0.8, normal_diff);
		normal_diff = clamp(normal_diff - neg_depth_diff, 0., 1.);
	}
	
	// --- BASE COLOR LOOKUP (Applies Pixelation if enabled) ---
	vec2 uv_for_color = SCREEN_UV;
	
	if (use_pixelation) {
		// Snap the UVs to a rigid, blocky grid
		vec2 grid_size = VIEWPORT_SIZE.xy / pixel_size;
		uv_for_color = round(SCREEN_UV * grid_size) / grid_size;
	}
	
	vec3 original_color = texture(SCREEN_TEXTURE, uv_for_color).rgb;
	vec3 final = original_color;
	
	// --- APPLY OUTLINES OVER THE COLOR ---
	if (highlights_enabled) {
		vec3 final_highlight_color = mix(original_color, highlight_color, highlight_strength);
		final = mix(final, final_highlight_color, normal_diff);
	}
	if (shadows_enabled) {
		vec3 final_shadow_color = mix(original_color, shadow_color, shadow_strength);
		final = mix(final, final_shadow_color, depth_diff);
	}
	
	ALBEDO = final;
	ROUGHNESS = 0.0;
	
	float alpha_mask = depth_diff * float(shadows_enabled) + normal_diff * float(highlights_enabled);
	ALPHA = clamp(alpha_mask * 5.0, 0.0, 1.0);
}