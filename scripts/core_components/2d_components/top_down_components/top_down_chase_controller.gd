@icon("uid://bp3gyc4rbmt5y")
class_name TopDownChaseController 
extends Node
## Calculates a direct line-of-sight movement vector towards a target.
##
## Sits between a [TopDownMoveTargeter] and a [TopDownMovement] component.
## It reads the desired target position and blindly moves towards it 
## without any obstacle avoidance.

# EXPORT VARIABLES
@export_group("References")
@export var parent: Node2D
@export var targeter_component: TopDownMoveTargeter ## The component providing the target coordinates.
@export var movement_component: TopDownMovement ## The component to send the calculated vector to.

@export_group("Settings")
@export var active: bool = true ## If false, stops calculating and sends a zero vector.

# BUILT-IN VIRTUAL METHODS
func _physics_process(_delta: float) -> void:
	_calculate_chase_vector()

# PRIVATE FUNCTIONS
func _calculate_chase_vector() -> void:
	# Check dependencies are valid
	if not movement_component or not targeter_component or not parent:
		push_warning("Chase Controller: Not all components assigned")
		return
		
	if not active or not targeter_component.targeting_enabled:
		movement_component.set_movement_direction(Vector2.ZERO)
		return
		
	# Calculate the exact normalized direction to the target
	var direction = parent.global_position.direction_to(targeter_component.target_position)
	
	# Send the command to the legs
	movement_component.set_movement_direction(direction)
