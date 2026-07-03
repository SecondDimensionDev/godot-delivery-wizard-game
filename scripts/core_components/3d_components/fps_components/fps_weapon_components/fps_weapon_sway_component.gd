class_name WeaponSwayComponent
extends Node3D
## Applies procedural sway to children based on mouse movement.
##
## Dragged behind the camera look to simulate weight.

# EXPORT VARIABLES
@export var sway_amount: float = 0.0002 ## Multiplier for mouse input to sway.
@export var max_sway: float = 0.08 ## Maximum rotation allowed in radians.
@export var sway_speed: float = 5.5 ## How fast the weapon returns to center.
@export var is_enabled: bool = true ## Toggles the sway effect.

# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
		
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * sway_amount
		rotation.x -= event.relative.y * sway_amount
		
		rotation.y = clampf(rotation.y, -max_sway, max_sway)
		rotation.x = clampf(rotation.x, -max_sway, max_sway)

func _process(delta: float) -> void:
	if not is_enabled:
		return
		
	# Smoothly return to center (0.0, 0.0)
	rotation.y = lerpf(rotation.y, 0.0, sway_speed * delta)
	rotation.x = lerpf(rotation.x, 0.0, sway_speed * delta)
