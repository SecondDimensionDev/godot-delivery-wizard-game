@icon("uid://nhq7tmbm02v7")
class_name TopDownMovement
extends Node
## Handles 2D top-down movement logic and physics for a [CharacterBody2D].
##
## This component takes a requested movement direction and smoothly calculates
## the resulting velocity based on acceleration and friction.[br]
## It directly applies this velocity to the assigned [member target_body] and
## calls [method CharacterBody2D.move_and_slide] internally.

# ENUMS
enum PhysicsMethod { SLIDE, COLLIDE }

# EXPORT VARIABLES
@export_group("References")
@export var target_body: CharacterBody2D ## The physics body to move. If left empty, defaults to parent.

@export_group("Physics")
@export var physics_method: PhysicsMethod = PhysicsMethod.SLIDE ## Choose how the body interacts with the world.

@export_group("Movement Stats")
@export var movement_enabled: bool = true ## If false, ignores requested direction and halts movement.
@export var max_speed: float = 150.0 ## The maximum speed in pixels per second.
@export var acceleration: float = 1400.0 ## How quickly the entity reaches max speed.
@export var friction: float = 1100.0 ## How quickly the entity stops when no direction is provided.

# PUBLIC VARIABLES
var current_direction := Vector2.ZERO ## The current requested movement direction.

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not target_body:
		target_body = get_parent() as CharacterBody2D
		if not target_body:
			push_error("TopDownMovement requires a CharacterBody2D parent or target_body.")


func _physics_process(delta: float) -> void:
	_apply_movement(delta)


# PUBLIC FUNCTIONS
func set_movement_direction(direction: Vector2) -> void: ## Sets the intended normalized direction for movement.
	if direction.length_squared() > 1.0:
		current_direction = direction.normalized()
	else:
		current_direction = direction


# PRIVATE FUNCTIONS
func _apply_movement(delta: float) -> void: # Calculates velocity and moves the target body.
	if not target_body:
		return
		
	var actual_direction := current_direction
	if not movement_enabled:
		actual_direction = Vector2.ZERO
		
	var target_velocity := actual_direction * max_speed
	
	if actual_direction != Vector2.ZERO:
		target_body.velocity = target_body.velocity.move_toward(target_velocity, acceleration * delta)
	else:
		target_body.velocity = target_body.velocity.move_toward(Vector2.ZERO, friction * delta)
		
	match physics_method:
		PhysicsMethod.SLIDE:
			target_body.move_and_slide()
		PhysicsMethod.COLLIDE:
			target_body.move_and_collide(target_body.velocity * delta)
