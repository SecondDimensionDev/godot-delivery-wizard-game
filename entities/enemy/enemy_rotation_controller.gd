class_name EnemyRotationController
extends Node
## Turns the Enemy's body to face a direction or point over time.
##
## Ported from the archived Listener/StoneChoir `_face_travel`/`_face_toward`
## helpers: a horizontal-only slerp at [member Enemy.behaviour_data].turn_rate.

# EXPORT VARIABLES
@export var parent: Enemy


# PUBLIC FUNCTIONS
func face_direction(direction: Vector3, delta: float) -> void: ## Slerps the body's facing toward direction (horizontal only).
	direction.y = 0.0
	if direction.length() < 0.0005:
		return

	var turn_rate: float = parent.behaviour_data.turn_rate if parent.behaviour_data else 6.0
	var desired := Quaternion(Basis.looking_at(direction.normalized(), Vector3.UP))
	parent.quaternion = parent.quaternion.slerp(desired, 1.0 - exp(-turn_rate * delta))


func face_point(point: Vector3, delta: float) -> void: ## Slerps the body's facing toward a world point (horizontal only).
	face_direction(point - parent.global_position, delta)
