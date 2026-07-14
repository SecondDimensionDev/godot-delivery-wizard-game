class_name LevitationSpell
extends Spell

@export var raycast: RayCast3D
@export var beam_pivot: Node3D
@export var lift_force: float = 15.0
@export var player_camera: Camera3D


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	beam_pivot.hide()


# PUBLIC FUNCTIONS
func start_cast() -> void:
	super()
	beam_pivot.show()


func process_cast(delta: float) -> void:
	super(delta)
	if player_camera:
		# Temporarily snap the raycast to the camera's exact position and rotation
		raycast.global_transform = player_camera.global_transform
	
	if not is_casting:
		return
		
	if raycast.is_colliding():
		var target = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		
		# 1. Point the beam exactly at the hit object
		beam_pivot.look_at(hit_point, Vector3.UP)
		
		# 2. Stretch the beam to match the distance
		var distance = global_position.distance_to(hit_point)
		beam_pivot.scale.z = distance
		
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
	
	else:
		# If we miss, maybe stretch the beam to the raycast's max length!
		beam_pivot.scale.z = raycast.target_position.z
		beam_pivot.rotation = Vector3.ZERO # Reset rotation to point straight forward


func stop_cast() -> void:
	super()
	beam_pivot.hide()


# PRIVATE FUNCTIONS
func _get_spell_receiver(hit_node: Node) -> SpellReceiver: # Helper function to search the hit object's children for the receiver
	for child in hit_node.get_children():
		if child is SpellReceiver:
			return child
	return null
