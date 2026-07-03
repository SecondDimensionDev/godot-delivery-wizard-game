class_name FPSCameraViewfinder
extends Camera3D
## Dynamically interpolates the camera's Field of View.
##
## Exposes public methods for other systems (like State Machines or Weapons)
## to request FOV changes for sprinting, aiming, or zooming.

# EXPORT VARIABLES
@export var base_fov: float = 75.0 ## The standard resting FOV.
@export var transition_speed: float = 10.0 ## How fast the FOV interpolates.

# PRIVATE VARIABLES
var _target_fov: float

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_target_fov = base_fov
	fov = base_fov


func _process(delta: float) -> void:
	if fov != _target_fov:
		fov = lerp(fov, _target_fov, transition_speed * delta)


# PUBLIC FUNCTIONS
func set_target_fov(new_fov: float) -> void: ## Requests a specific FOV to transition to.
	_target_fov = new_fov


func reset_fov() -> void: ## Returns the target FOV back to the base value.
	_target_fov = base_fov
