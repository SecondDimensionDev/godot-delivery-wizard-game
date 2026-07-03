shader_type spatial;
// cull_disabled shows both sides of the mesh. 
// depth_draw_opaque is required for perfect Alpha Scissor rendering.
render_mode cull_disabled, diffuse_toon, depth_draw_opaque;

group_uniforms Textures_and_Colors;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;
uniform vec3 base_color : source_color = vec3(0.35, 0.5, 0.2);
uniform vec3 variance_color : source_color = vec3(0.45, 0.6, 0.25);
uniform bool use_upward_normals = true;

group_uniforms Wind_Settings;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.15;

group_uniforms Performance;
uniform float cull_distance = 60.0; // Distance where grass completely disappears
uniform float fade_distance = 10.0; // How many meters it takes to shrink to size 0

varying float rand_val;

void vertex() {
	rand_val = INSTANCE_CUSTOM.r;
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	
	// DISTANCE CULLING
	float dist = distance(CAMERA_POSITION_WORLD, world_pos);
	float scale = 1.0 - smoothstep(cull_distance - fade_distance, cull_distance, dist);
	VERTEX *= scale;
	
	// WIND SWAY
	float height_factor = 1.0 - UV.y; 
	float time = (TIME * wind_speed) + (world_pos.x * 0.5) + (world_pos.z * 0.5) + (rand_val * 5.0);
	vec2 wind_offset = wind_direction * sin(time) * wind_strength * height_factor * scale;
	
	VERTEX.x += wind_offset.x;
	VERTEX.z += wind_offset.y;
}

void fragment() {
	// Read the PNG texture
	vec4 tex = texture(grass_texture, UV);
	
	// Discard transparent pixels immediately to create the grass shape
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	
	// Apply our color variance and a fake shadow at the root (UV.y == 1.0)
	vec3 final_color = mix(base_color, variance_color, rand_val);
	float ao = mix(0.5, 1.0, 1.0 - UV.y);
	
	// Multiply the texture color by our procedural colors
	ALBEDO = final_color * tex.rgb * ao;
	//ROUGHNESS = 0.8;
	ROUGHNESS = 0.0;
	
	if (use_upward_normals) {
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
}