class_name TopDownMovement3D
extends Node
## Handles 3D top-down movement logic and physics for a CharacterBody3D.
##
## Takes a requested movement direction and smoothly calculates velocity
## based on acceleration and friction. Applies gravity and handles jumping.

# EXPORT VARIABLES
@export_group("References")
@export var target_body: CharacterBody3D ## The physics body to move. If left empty, defaults to parent.

@export_group("Movement Stats")
@export var movement_enabled: bool = true ## If false, ignores requested direction and halts movement.
@export var max_speed: float = 10.0 ## The maximum speed in units per second.
@export var acceleration: float = 60.0 ## How quickly the entity reaches max speed.
@export var friction: float = 50.0 ## How quickly the entity stops when no direction is provided.

@export_group("Gravity & Jumping")
@export var gravity_multiplier: float = 1.0 ## Multiplies the global gravity applied to this entity.
@export var jump_force: float = 12.0 ## The upward velocity applied when jumping.

# PUBLIC VARIABLES
var current_direction: Vector3 = Vector3.ZERO ## The current requested movement direction.

# PRIVATE VARIABLES
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not target_body:
		target_body = get_parent() as CharacterBody3D
	if not target_body:
		push_error("TopDownMovement3D requires a CharacterBody3D parent or target_body.")

func _physics_process(delta: float) -> void:
	_apply_movement(delta)

# PUBLIC FUNCTIONS
func set_movement_direction(direction: Vector3) -> void:
	## Sets the intended normalized direction for movement.
	if direction.length_squared() > 1.0:
		current_direction = direction.normalized()
	else:
		current_direction = direction

func jump() -> void:
	## Applies an upward impulse if the character is currently on the floor.
	if not target_body or not movement_enabled:
		return
		
	if target_body.is_on_floor():
		target_body.velocity.y = jump_force

# PRIVATE FUNCTIONS
func _apply_movement(delta: float) -> void:
	if not target_body:
		return

	var actual_direction := current_direction
	if not movement_enabled:
		actual_direction = Vector3.ZERO

	# 1. Handle Gravity
	if not target_body.is_on_floor():
		target_body.velocity.y -= _gravity * gravity_multiplier * delta

	# 2. Handle X/Z Movement
	var target_velocity := actual_direction * max_speed
	var current_xz := Vector3(target_body.velocity.x, 0.0, target_body.velocity.z)
	var new_xz := Vector3.ZERO

	if actual_direction != Vector3.ZERO:
		new_xz = current_xz.move_toward(target_velocity, acceleration * delta)
	else:
		new_xz = current_xz.move_toward(Vector3.ZERO, friction * delta)

	# 3. Apply the final combined velocity
	target_body.velocity.x = new_xz.x
	target_body.velocity.z = new_xz.z
	
	target_body.move_and_slide()
