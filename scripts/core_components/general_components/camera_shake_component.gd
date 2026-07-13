class_name CameraShakeComponent
extends Node3D

## Attach as a child of a camera rig. Offsets the parent camera with decaying random
## noise while [member trauma] is above zero -- call [method shake] to add trauma
## (e.g. in response to a locally-relevant gameplay event); nothing outside this node
## needs to know how the shake itself is implemented.

# EXPORT VARIABLES
@export var camera: Camera3D
@export var max_offset: Vector3 = Vector3(0.2, 0.2, 0.0) ## Max positional shake per axis.
@export var max_roll: float = 0.05 ## Max roll shake, in radians.
@export var decay_per_second: float = 2.0 ## How fast trauma drains back to zero.

# PRIVATE VARIABLES
var _trauma: float = 0.0
var _rng := RandomNumberGenerator.new()


# BUILT-IN VIRTUAL METHODS
func _physics_process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - decay_per_second * delta)
	var amount := _trauma * _trauma # decaying feel: falls off faster near zero
	camera.h_offset = max_offset.x * amount * _rng.randf_range(-1.0, 1.0)
	camera.v_offset = max_offset.y * amount * _rng.randf_range(-1.0, 1.0)
	camera.rotation.z = max_roll * amount * _rng.randf_range(-1.0, 1.0)
	if _trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0


# PUBLIC FUNCTIONS
func shake(strength: float, duration_ms: int) -> void: ## Adds trauma; decays over duration_ms.
	var added := clampf(strength, 0.0, 1.0)
	_trauma = clampf(_trauma + added, 0.0, 1.0)
	if duration_ms > 0:
		decay_per_second = 1.0 / (float(duration_ms) / 1000.0)
