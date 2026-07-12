class_name LevitationSpell
extends Spell

@export var parent: PlayerMagicSpells
@export var raycast: RayCast3D
@export var lift_force: float = 15.0

func process_cast(delta: float) -> void:
	super(delta)
	if not is_casting:
		return
		
	# Check if our beam is hitting something
	if raycast.is_colliding():
		var target = raycast.get_collider()
		
		# Ensure the object we hit is a physics body that can be moved
		if target is RigidBody3D:
			# Apply a continuous upward force to fight gravity
			target.apply_central_force(Vector3.UP * lift_force)
