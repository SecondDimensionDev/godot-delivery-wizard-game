class_name HitscanFireBehavior
extends WeaponFireBehavior
## Handles instant-hit (hitscan) weapon logic perfectly aligned to the screen center.
##
## Snaps a RayCast3D to the active camera to ensure pixel-perfect retro accuracy.
## It broadcasts impacts to the EventBus for decals and applies damage
## if the impacted object has a valid receiver.

# EXPORT VARIABLES
@export var parent_weapon: BaseWeapon
@export var raycast: RayCast3D ## The raycast used to detect hits.

# PUBLIC VARIABLES
var max_distance: float = 100.0 ## The maximum range of the hitscan in meters.

# BUILT-IN VIRTUAL FUNCTIONS
func _ready()-> void:
	if parent_weapon and parent_weapon.weapon_data:
		max_distance = parent_weapon.weapon_data.weapon_range


# PUBLIC FUNCTIONS
func fire(weapon_data: FPSWeaponData) -> void: ## Fires the hitscan ray and processes impacts.
	if not is_instance_valid(raycast):
		push_warning("HitscanFireBehavior: No RayCast3D assigned.")
		return
		
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Temporarily snap the raycast to the camera's exact position and rotation
		raycast.global_transform = camera.global_transform
		
	# Calculate random spread
	var spread := weapon_data.bullet_spread
	var random_x := randf_range(-spread, spread)
	var random_y := randf_range(-spread, spread)
	
	# Set the forward distance limit with the spread applied
	raycast.target_position = Vector3(random_x, random_y, -max_distance)
	
	# Force the raycast to update immediately to prevent 1-frame lag
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var hit_point := raycast.get_collision_point()
		var hit_normal := raycast.get_collision_normal()
		var collider := raycast.get_collider()
		
		# 1. Broadcast the impact to the environment for VFX/Decals
		EventBus.environment.bullet_impact.emit(hit_point, hit_normal, weapon_data.bullet_impact_scene)
		
		# 2. Try to deal damage
		if collider.has_method("damage"):
			collider.damage(weapon_data.base_damage)
		else:
			for child in collider.get_children():
				if child is HitPointComponent:
					child.damage(weapon_data.base_damage)
					break
