class_name FPSRecoilComponent
extends Node3D
## Applies procedural, spring-based camera recoil for a snappy, arcade feel.
##
## This node should be placed in the camera rig, as a child of the PitchNode, 
## and as the parent of the WorldCamera. Call [method add_recoil] when the 
## active weapon fires.

# PRIVATE VARIABLES
var _recoil_rotation: Vector3 = Vector3(0.05, 0.02, 0.01)
var _snap_amount: float = 25.0
var _recovery_speed: float = 10.0
var _random_variance: float = 0.5
var _target_rotation: Vector3 = Vector3.ZERO
var _current_rotation: Vector3 = Vector3.ZERO

# BUILT-IN VIRTUAL METHODS
func _process(delta: float) -> void:
	# 1. Decay the target rotation back to zero over time (The Rubber-Band)
	_target_rotation = _target_rotation.lerp(Vector3.ZERO, _recovery_speed * delta)
	
	# 2. Snappy interpolation of the actual rotation to the target (The Violent Kick)
	_current_rotation = _current_rotation.lerp(_target_rotation, _snap_amount * delta)
	
	# 3. Apply the rotation to this Node3D
	rotation = _current_rotation


# PUBLIC FUNCTIONS
func add_recoil(recoil_rotation: Vector3, snap_amount: float , recovery_speed: float, random_variance: float) -> void: ## Applies the recoil impulse. Connect this to the weapon's 'fired' signal.
	_recoil_rotation = recoil_rotation
	_snap_amount = snap_amount
	_recovery_speed = recovery_speed
	_random_variance = random_variance

	var random_yaw := randf_range(-_recoil_rotation.y, _recoil_rotation.y) * _random_variance
	var random_roll := randf_range(-_recoil_rotation.z, _recoil_rotation.z) * _random_variance
	
	# Note: In Godot, positive X rotates the node upward. 
	var kick := Vector3(_recoil_rotation.x, random_yaw, random_roll)
	
	_target_rotation += kick
