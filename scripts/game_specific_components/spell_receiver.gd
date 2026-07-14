class_name SpellReceiver
extends Node

@export var target_body: RigidBody3D

# Accumulators to store incoming magic forces
var _accumulated_force: Vector3 = Vector3.ZERO
var _accumulated_torque: Vector3 = Vector3.ZERO

## This RPC can be called by anyone, runs locally if cast by the host, 
## and is 'unreliable' for speed (perfect for continuous beams).
@rpc("any_peer", "call_local", "unreliable")
func receive_magic_forces(linear_force: Vector3, torque: Vector3) -> void:
	_accumulated_force += linear_force
	_accumulated_torque += torque


func _physics_process(_delta: float) -> void:
	# 1. Safety check & Authority check
	if not target_body or not target_body.is_multiplayer_authority():
		# Clear forces on network puppets so they don't build up ghost data
		_accumulated_force = Vector3.ZERO
		_accumulated_torque = Vector3.ZERO
		return
		
	# 2. Apply all accumulated linear forces (Levitation, Push, Pull)
	if _accumulated_force != Vector3.ZERO:
		target_body.apply_central_force(_accumulated_force)
		_accumulated_force = Vector3.ZERO
		
	# 3. Apply all accumulated rotational forces (Spinning)
	if _accumulated_torque != Vector3.ZERO:
		target_body.apply_torque(_accumulated_torque)
		_accumulated_torque = Vector3.ZERO
