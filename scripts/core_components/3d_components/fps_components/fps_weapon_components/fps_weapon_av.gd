class_name FPSWeaponAV
extends Node

# EXPORT VARIABLES
@export_group("Dependencies")
@export var weapon_parent: BaseWeapon
@export var muzzle_flash_container: Node3D

@export_group("Viewmodel Settings")
@export var auto_setup_viewmodel: bool = true
@export var viewmodel_fov: float = 50.0 ## The FOV override value for this weapon.
@export var z_clip_scale: float = 0.75 ## The clip scale to prevent wall clipping.
@export var viewmodel_meshes: Array[MeshInstance3D] = [] ## Assign weapon meshes here.
@export var viewmodel_particles: Array[GPUParticles3D] = [] ## Assign muzzle flashes here.

@export_group("Muzzle Flash")
@export var use_muzzle_flash: bool = true
@export var muzzle_flash: MeshInstance3D
@export var use_muzzle_light: bool = true
@export var muzzle_light: OmniLight3D
@export var flash_timing: float = 0.1
@export var use_muzzle_sparks: bool = true
@export var muzzle_flash_sparks: GPUParticles3D
@export var use_muzzle_smoke: bool = true
@export var muzzle_smoke: GPUParticles3D

@export_group("Sound Effects")
@export_subgroup("Fire SFX")
@export var fire_sound: AudioStream
@export var pitch_fire_vary: float = 0.05
@export var volume_fire_vary: float = 0.01
@export_subgroup("Clip SFX")
@export var empty_clip_sound: AudioStream
@export var pitch_empty_clip_vary: float = 0.02
@export var volume_empty_clip_vary: float = 0.01

@export var insert_clip_sound: AudioStream
@export var pitch_insert_clip_vary: float = 0.00
@export var volume_insert_clip_vary: float = 0.00

@export var remove_clip_sound: AudioStream
@export var pitch_remove_clip_vary: float = 0.02
@export var volume_remove_clip_vary: float = 0.01

@export_subgroup("Reload SFX")
@export var reload_sound: AudioStream
@export var pitch_reload_vary: float = 0.0
@export var volume_reload_vary: float = 0.0
@export_subgroup("Equip SFX")
@export var equip_sound: AudioStream
@export var pitch_equip_vary: float = 0.0
@export var volume_equip_vary: float = 0.0
@export_subgroup("Unequip SFX")
@export var unequip_sound: AudioStream
@export var pitch_unequip_vary: float = 0.0
@export var volume_unequip_vary: float = 0.0
@export_subgroup("Prime SFX")
@export var prime_sound: AudioStream
@export var pitch_prime_vary: float = 0.0
@export var volume_prime_vary: float = 0.0


# PRIVATE VARIABLES

# PRIVATE BUILT-IN FUNCTIONS
func _ready() -> void:
	if auto_setup_viewmodel:
		_setup_viewmodel_materials.call_deferred()
	
	if use_muzzle_flash and muzzle_flash:
		muzzle_flash.visible = false
	
	if use_muzzle_light and muzzle_light:
		muzzle_light.visible = false


# PUBLIC FUNCTIONS
func emit_muzzle_flash() -> void:
	if use_muzzle_flash and muzzle_flash:
		muzzle_flash.visible = true
	
	if use_muzzle_light and muzzle_light:
		muzzle_light.visible = true
	
	if use_muzzle_flash or use_muzzle_light:
		get_tree().create_timer(flash_timing).timeout.connect(_hide_muzzle_flash)
	
	if use_muzzle_sparks and muzzle_flash_sparks:
		muzzle_flash_sparks.restart()
	
	if use_muzzle_smoke and muzzle_smoke:
		muzzle_smoke.restart()


func play_fire_sound() -> void:
	if fire_sound:
		AudioPlayer.sfx.play_sound(fire_sound, pitch_fire_vary, volume_fire_vary)


func play_reload_sound() -> void:
	if reload_sound:
		AudioPlayer.sfx.play_sound(reload_sound, pitch_reload_vary, volume_reload_vary)


func play_empty_clip_sound() -> void:
	if empty_clip_sound:
		AudioPlayer.sfx.play_sound(empty_clip_sound, pitch_empty_clip_vary, volume_empty_clip_vary)


func play_equip_sound() -> void:
	if equip_sound:
		AudioPlayer.sfx.play_sound(equip_sound, pitch_equip_vary, volume_equip_vary)


func play_unequip_sound() -> void:
	if unequip_sound:
		AudioPlayer.sfx.play_sound(unequip_sound, pitch_unequip_vary, volume_unequip_vary)


func play_prime_sound() -> void:
	if prime_sound:
		AudioPlayer.sfx.play_sound(prime_sound, pitch_prime_vary, volume_prime_vary)

func play_remove_clip_sound() -> void:
	if remove_clip_sound:
		AudioPlayer.sfx.play_sound(remove_clip_sound, pitch_remove_clip_vary, volume_remove_clip_vary)

func play_insert_clip_sound() -> void:
	if insert_clip_sound:
		AudioPlayer.sfx.play_sound(insert_clip_sound, pitch_insert_clip_vary, volume_insert_clip_vary)



# PRIVATE FUNCTIONS
func _setup_viewmodel_materials() -> void: # Automates the FOV and Z-Clip material settings
	# 1. Update standard meshes
	for mesh_node in viewmodel_meshes:
		if not is_instance_valid(mesh_node) or not mesh_node.mesh:
			continue
			
		for i in range(mesh_node.mesh.get_surface_count()):
			var mat := mesh_node.get_active_material(i)
			
			# Fallback if no active override is found
			if not mat:
				mat = mesh_node.mesh.surface_get_material(i)
				
			if mat:
				var new_mat := mat.duplicate()
				new_mat.set("use_fov_override", true)
				new_mat.set("fov_override", viewmodel_fov) 
				new_mat.set("use_z_clip_scale", true)
				new_mat.set("z_clip_scale", z_clip_scale)
				
				mesh_node.set_surface_override_material(i, new_mat)
				
	# 2. Update particle systems
	for particle_node in viewmodel_particles:
		if not is_instance_valid(particle_node):
			continue
			
		var mat := particle_node.material_override
		
		# If no override is set, try to grab the material from the first draw pass
		if not mat and particle_node.draw_passes > 0:
			var pass_mesh := particle_node.get_draw_pass_mesh(0)
			if pass_mesh:
				mat = pass_mesh.surface_get_material(0)
				
		if mat:
			var new_mat := mat.duplicate()
			new_mat.set("use_fov_override", true)
			new_mat.set("fov_override", viewmodel_fov)
			new_mat.set("use_z_clip_scale", true)
			new_mat.set("z_clip_scale", z_clip_scale)
			
			# Applying to material_override safely modifies the particles 
			# without permanently altering the source mesh
			particle_node.material_override = new_mat

func _hide_muzzle_flash() -> void:
	if use_muzzle_flash:
		muzzle_flash.visible = false
	if use_muzzle_light:
		muzzle_light.visible = false
