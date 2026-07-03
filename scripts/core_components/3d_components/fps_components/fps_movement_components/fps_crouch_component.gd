class_name PlayerCrouchComponent
extends Node
## Handles the physical resizing of the player's collision and camera height.
##
## Smoothly interpolates the capsule height and camera position. 
## Requires a RayCast3D pointing straight up to prevent standing inside geometry.

# EXPORT VARIABLES
@export_group("Target Nodes")
@export var collision_shape: CollisionShape3D ## The player's main physics collider.
@export var camera_anchor: Marker3D ## The anchor node the head syncs to.
@export var ceiling_check: RayCast3D ## Raycast pointing UP to check for clearance.

@export_group("Crouch Settings")
@export var crouch_speed: float = 8.0 ## How fast the transition happens.
@export var standing_height: float = 2.0 ## The default height of the capsule.
@export var crouching_height: float = 1.0 ## The height of the capsule when crouched.

# PRIVATE VARIABLES
var _is_crouching: bool = false
var _target_height: float
var _target_camera_y: float
var _target_collision_y: float

var _default_camera_y: float
var _default_collision_y: float

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Store the baseline positions on spawn so we can return to them
	_default_camera_y = camera_anchor.position.y
	_default_collision_y = collision_shape.position.y
	
	_target_height = standing_height
	_target_camera_y = _default_camera_y
	_target_collision_y = _default_collision_y

func _process(delta: float) -> void:
	if not is_instance_valid(collision_shape) or not collision_shape.shape is CapsuleShape3D:
		return
		
	var capsule := collision_shape.shape as CapsuleShape3D
	
	# Smoothly interpolate the properties
	capsule.height = lerpf(capsule.height, _target_height, crouch_speed * delta)
	camera_anchor.position.y = lerpf(camera_anchor.position.y, _target_camera_y, crouch_speed * delta)
	collision_shape.position.y = lerpf(collision_shape.position.y, _target_collision_y, crouch_speed * delta)

# PUBLIC FUNCTIONS
func crouch() -> void: ## Triggers the crouch transition.
	_is_crouching = true
	_target_height = crouching_height
	
	# Calculate the height difference to lower the nodes
	var height_diff := standing_height - crouching_height
	_target_camera_y = _default_camera_y - height_diff
	_target_collision_y = _default_collision_y - (height_diff / 2.0) # Capsule shrinks from center, so only move half

func uncrouch() -> void: ## Triggers the stand transition.
	_is_crouching = false
	_target_height = standing_height
	_target_camera_y = _default_camera_y
	_target_collision_y = _default_collision_y

func can_stand() -> bool: ## Checks if there is enough room above the player to stand up.
	if is_instance_valid(ceiling_check):
		ceiling_check.force_raycast_update()
		return not ceiling_check.is_colliding()
	return true
