class_name LevitationSpell
extends Spell

@export var raycast: RayCast3D
@export var lift_force: float = 15.0
@export var player_camera: Camera3D

func process_cast(delta: float) -> void:
	super(delta)
	if player_camera:
		# Temporarily snap the raycast to the camera's exact position and rotation
		raycast.global_transform = player_camera.global_transform
	
	if not is_casting:
		return
		
	if raycast.is_colliding():
		var target = raycast.get_collider()
		
		if target is Node:
			# Look for our custom component on the hit object
			var receiver = _get_spell_receiver(target)
			if receiver:
				# Define our forces
				var force_vector = Vector3.UP * lift_force
				var torque_vector = Vector3.ZERO 
				
				# Send the forces directly to whoever is simulating this box's physics
				var authority_id = receiver.get_multiplayer_authority()
				receiver.rpc_id(authority_id, "receive_magic_forces", force_vector, torque_vector)


## Helper function to search the hit object's children for the receiver
func _get_spell_receiver(hit_node: Node) -> SpellReceiver:
	for child in hit_node.get_children():
		if child is SpellReceiver:
			return child
	return null
