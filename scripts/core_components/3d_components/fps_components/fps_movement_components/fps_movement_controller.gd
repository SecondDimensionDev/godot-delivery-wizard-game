class_name FPSMovementController
extends Node
## Component responsible for handling 3D character physics and movement.
##
## Features kinematic jump calculations (height/time) and momentum-based
## acceleration/deceleration for fine-tuned game feel.

# EXPORT VARIABLES
@export var body: CharacterBody3D ## The physics body to move.

@export_group("Speed & Momentum")
@export var base_speed: float = 11.0 ## Top horizontal movement speed.
@export var acceleration: float = 100.0 ## How fast the player reaches top speed.
@export var deceleration: float = 70.0 ## How fast the player stops when keys are released.
@export var run_mulitplier: float = 1.5 ## increases max speed when running.
@export var crouch_mulitplier: float = 0.7 ## Reduces max speed when crouching.
@export var air_control: bool = false ## If false, player cannot change direction in mid-air.
@export var air_multiplier: float = 0.5 ## Reduces acceleration/deceleration while airborne.

@export_group("Jump Physics")
@export var jump_height: float = 3.0 ## Peak height of the jump in meters.
@export var time_to_apex: float = 0.4 ## Seconds it takes to reach the peak height.
@export var fall_gravity_multiplier: float = 1.4 ## Multiplies gravity when falling for a heavier feel.

# PRIVATE VARIABLES
var _jump_gravity: float
var _fall_gravity: float
var _jump_velocity: float

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_calculate_jump_physics()

# PUBLIC FUNCTIONS
func apply_gravity(delta: float) -> void: ## Applies calculated gravity based on upward/downward velocity.
	if not body.is_on_floor():
		# Use heavier gravity if we are falling (velocity <= 0)
		var current_gravity := _jump_gravity if body.velocity.y > 0.0 else _fall_gravity
		body.velocity.y -= current_gravity * delta

func jump() -> void: ## Applies calculated jump velocity.
	if body.is_on_floor():
		body.velocity.y = _jump_velocity

func move(direction: Vector3, delta: float, speed_modifier: float = 1.0) -> void: ## Calculates momentum and moves the body.
	if not air_control and not body.is_on_floor():
		body.move_and_slide()
		return

	var target_speed := base_speed * speed_modifier
	var target_velocity := direction * target_speed
	
	# Determine if we are trying to speed up or slow down
	var accel_rate := acceleration if direction != Vector3.ZERO else deceleration
	
	# Make movement slightly more "slippery" in the air
	if not body.is_on_floor():
		accel_rate *= air_multiplier

	# Interpolate current velocity toward the target velocity over time
	body.velocity.x = move_toward(body.velocity.x, target_velocity.x, accel_rate * delta)
	body.velocity.z = move_toward(body.velocity.z, target_velocity.z, accel_rate * delta)

	body.move_and_slide()

# PRIVATE FUNCTIONS
func _calculate_jump_physics() -> void: # Derives velocity and gravity from height and time variables.
	_jump_gravity = (2.0 * jump_height) / (time_to_apex * time_to_apex)
	_jump_velocity = _jump_gravity * time_to_apex
	_fall_gravity = _jump_gravity * fall_gravity_multiplier
