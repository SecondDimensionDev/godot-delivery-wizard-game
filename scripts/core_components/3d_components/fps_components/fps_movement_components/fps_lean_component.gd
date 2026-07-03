class_name PlayerLeanComponent
extends Node3D
## Handles leaning left and right to peer around corners.
##
## Requires a RayCast3D child node to prevent clipping through walls.
## The RayCast3D should be set to collide with environment physics layers.

# EXPORT VARIABLES
@export_group("Lean Settings")
@export var lean_enabled: bool = false ## FPS Camera will listen for Lean inputs
@export var _raycast: RayCast3D
@export var lean_angle: float = 15.0 ## The maximum rotation in degrees.
@export var lean_distance: float = 0.5 ## How far the camera moves horizontally in meters.
@export var lean_speed: float = 8.0 ## How fast the player leans and returns to center.
@export var wall_buffer: float = 0.15 ## Keeps the camera slightly away from the wall to prevent near-plane clipping.

#PUBLIC VARIABLE
var can_lean: bool = false ## Controls if the player can input lean commands

# PRIVATE VARIABLES
var _target_rotation_z: float = 0.0
var _target_position_x: float = 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if not lean_enabled:
		return
		
	_calculate_lean_targets()
	
	# Smoothly interpolate rotation (Roll)
	rotation.z = lerpf(rotation.z, _target_rotation_z, lean_speed * delta)
	
	# Smoothly interpolate position (Horizontal step)
	position.x = lerpf(position.x, _target_position_x, lean_speed * delta)


# PRIVATE FUNCTIONS
func _calculate_lean_targets() -> void:
	var lean_dir := 0.0
	# Only accept input if we are allowed to lean
	if can_lean:
		lean_dir = Input.get_axis("lean_right", "lean_left")
	
	if lean_dir != 0.0:
		_target_rotation_z = deg_to_rad(lean_angle) * lean_dir
		_target_position_x = lean_distance * -lean_dir
		
		# --- THE WALL CHECK ---
		if is_instance_valid(_raycast):
			# Point the raycast toward our desired lean position
			_raycast.target_position = Vector3(_target_position_x, 0, 0)
			_raycast.force_raycast_update()
			
			if _raycast.is_colliding():
				# If we hit a wall, find the distance to the hit point in local space
				var hit_point := to_local(_raycast.get_collision_point())
				
				# Clamp our target position, keeping a small buffer away from the wall
				var safe_distance := absf(hit_point.x) - wall_buffer
				if safe_distance > 0:
					_target_position_x = safe_distance * -lean_dir
				else:
					_target_position_x = 0.0 # Don't lean physically if we are pressed against the wall
	else:
		_target_rotation_z = 0.0
		_target_position_x = 0.0
