shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Damage feedback: tint darkens, a wounded red bias creeps in, and world-space
// procedural cracks densify as `damage` climbs from 0 (pristine) to 1 (worthless).
// Driven per-frame by Cargo.gd from the replicated `value` -- purely cosmetic.

uniform vec3 albedo : source_color = vec3(0.85, 0.5, 0.2);
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float crack_scale = 3.0;
uniform vec3 damage_tint : source_color = vec3(0.6, 0.05, 0.05);

// Cheap hash-based value noise so we don't ship a texture.
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = mix(
		mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
	return n;
}

void fragment() {
	// Darken as damage rises.
	vec3 base = mix(albedo, albedo * 0.4, damage);
	// Wounded red bias.
	base = mix(base, damage_tint, damage * 0.35);
	// World-space cracks: threshold shrinks as damage climbs, so cracks spread.
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = noise(world_pos * crack_scale);
	float crack_threshold = mix(1.0, 0.45, damage); // none at 0; visible from ~0.55
	float crack = smoothstep(crack_threshold, crack_threshold - 0.05, n);
	base *= 1.0 - crack * 0.75;
	ALBEDO = base;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
