class_name WeaponTiltComponent
extends Node3D
## Applies procedural roll (tilt) to children based on horizontal mouse movement.

# EXPORT VARIABLES
@export var tilt_amount: float = 0.0001 ## Multiplier for mouse X input to Z tilt.
@export var max_tilt: float = 0.1 ## Maximum tilt allowed in radians.
@export var tilt_speed: float = 5.0 ## How fast the weapon returns to level.
@export var is_enabled: bool = true ## Toggles the tilt effect.

# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
		
	if event is InputEventMouseMotion:
		# Note: Change to += if you prefer the tilt inverted
		rotation.z -= event.relative.x * tilt_amount
		rotation.z = clampf(rotation.z, -max_tilt, max_tilt)

func _process(delta: float) -> void:
	if not is_enabled:
		return
		
	rotation.z = lerpf(rotation.z, 0.0, tilt_speed * delta)
