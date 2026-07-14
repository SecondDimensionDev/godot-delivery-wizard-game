class_name EnemyMovementController
extends Node
## Component responsible for moving the Enemy's CharacterBody3D toward a point.
##
## A simplified counterpart to FPSMovementController: no acceleration curve or
## jump physics, just constant-speed horizontal movement (per
## [member Enemy.behaviour_data]) plus gravity so the body stays grounded.

# EXPORT VARIABLES
@export var parent: Enemy


# PRIVATE VARIABLES
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


# PUBLIC FUNCTIONS
func move_toward_point(target: Vector3, delta: float) -> void: ## Steps the body horizontally toward target at behaviour_data.move_speed.
	_apply_gravity(delta)

	var to_target := target - parent.global_position
	to_target.y = 0.0

	var speed: float = parent.behaviour_data.move_speed if parent.behaviour_data else 0.0

	if to_target.length() < 0.01:
		parent.velocity.x = 0.0
		parent.velocity.z = 0.0
	else:
		var direction := to_target.normalized()
		parent.velocity.x = direction.x * speed
		parent.velocity.z = direction.z * speed

	parent.move_and_slide()


func stop(delta: float) -> void: ## Zeroes horizontal velocity while still applying gravity/collision.
	_apply_gravity(delta)
	parent.velocity.x = 0.0
	parent.velocity.z = 0.0
	parent.move_and_slide()


# PRIVATE FUNCTIONS
func _apply_gravity(delta: float) -> void:
	if not parent.is_on_floor():
		parent.velocity.y -= _gravity * delta
