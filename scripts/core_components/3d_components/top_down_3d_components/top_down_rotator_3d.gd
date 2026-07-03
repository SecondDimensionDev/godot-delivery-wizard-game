@icon("uid://bv1ydtultdjrt") 
class_name TopDownVisualRotator3D
extends Node
## Rotates or flips a visual 3D node based on movement direction.
##
## Monitors a [TopDownMovement3D] component and automatically applies either
## smooth Y-axis rotation (for 3D meshes) or horizontal flipping (for Sprite3D)
## based on the current 3D velocity.

# ENUMS
enum RotationMode { Y_AXIS_ROTATION, SPRITE_FLIP }

# EXPORT VARIABLES
@export_group("References")
@export var target_visuals: Node3D ## The visual node to manipulate (MeshInstance3D, Node3D, or Sprite3D).
@export var movement_component: TopDownMovement3D ## The component supplying the movement vector.
@export var reference_camera: Camera3D ## Optional: Used to ensure Sprite3D flips accurately relative to the screen.

@export_group("Settings")
@export var rotation_mode: RotationMode = RotationMode.Y_AXIS_ROTATION ## Choose between true 3D rotation or 2D-style flipping.

@export_subgroup("Y-Axis Rotation Settings")
@export var rotation_speed: float = 15.0 ## How smoothly the mesh turns to face the movement direction.

@export_subgroup("Sprite Flip Settings")
@export var flip_horizontal: bool = true ## Should the sprite flip left/right?
@export var default_facing_right: bool = true ## True if the original art faces right.

# BUILT-IN VIRTUAL METHODS
func _physics_process(delta: float) -> void:
	_update_rotation(delta)

# PRIVATE FUNCTIONS
func _update_rotation(delta: float) -> void:
	if not target_visuals or not movement_component:
		return

	var direction := movement_component.current_direction
	if direction == Vector3.ZERO:
		return

	match rotation_mode:
		RotationMode.Y_AXIS_ROTATION:
			_process_y_axis_rotation(direction, delta)
		RotationMode.SPRITE_FLIP:
			_process_sprite_flip(direction)

func _process_y_axis_rotation(direction: Vector3, delta: float) -> void:
	# Ensure we only rotate on the horizontal plane
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	
	if flat_direction.length_squared() < 0.001:
		return
		
	var target_pos := target_visuals.global_position + flat_direction
	var current_transform := target_visuals.global_transform
	
	# Create a target transform looking in the movement direction
	# UP vector is strictly Vector3.UP to prevent tilting
	var target_transform := current_transform.looking_at(target_pos, Vector3.UP)
	
	# Smoothly interpolate the current basis towards the target basis
	target_visuals.global_transform = current_transform.interpolate_with(target_transform, rotation_speed * delta)

func _process_sprite_flip(direction: Vector3) -> void:
	# Ensure the target actually has a flip_h property before trying to set it
	if not "flip_h" in target_visuals:
		push_warning("TopDownVisualRotator3D: Target visual does not have a 'flip_h' property.")
		return

	var right_dot_product: float = 0.0

	# If a camera is assigned, check if we are moving "right" relative to the screen
	if is_instance_valid(reference_camera):
		var cam_right := reference_camera.global_transform.basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()
		right_dot_product = direction.dot(cam_right)
	else:
		# Fallback: Just use the world X axis
		right_dot_product = direction.x

	# Apply the flip logic based on the dot product (positive = right, negative = left)
	if right_dot_product > 0.01:
		target_visuals.flip_h = not default_facing_right
	elif right_dot_product < -0.01:
		target_visuals.flip_h = default_facing_right
