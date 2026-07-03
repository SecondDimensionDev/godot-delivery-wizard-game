class_name DecalManager
extends Node
## Listens for impact events and spawns decals.
##
## Manages a pool of active decals to prevent memory leaks and performance drops.
## When the maximum limit is reached, the oldest decal is instantly removed.

# EXPORT VARIABLES
@export_group("Configuration")
@export var default_decal_scene: PackedScene ## The Decal scene to instantiate.
@export var max_decals: int = 50 ## The maximum number of decals allowed at once.

# PRIVATE VARIABLES
var _active_decals: Array[Node3D] = []

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	EventBus.environment.bullet_impact.connect(_on_bullet_impact)

# PRIVATE FUNCTIONS
func _on_bullet_impact(hit_position: Vector3, hit_normal: Vector3, decal_scene: PackedScene) -> void: # Spawns and aligns the decal
	
	var scene_to_spawn := decal_scene if is_instance_valid(decal_scene) else default_decal_scene
	
	if not is_instance_valid(scene_to_spawn):
		push_warning("DecalManager: No bullet hole scene assigned.")
		return
		
	var decal := scene_to_spawn.instantiate() as Node3D
	add_child(decal)
	
	# 1. Move to the exact hit position
	decal.global_position = hit_position
	
	# 2. Align the decal to be flush with the wall normal
	var up_vector := Vector3.UP
	if absf(hit_normal.y) > 0.99:
		up_vector = Vector3.RIGHT
		
	decal.look_at(hit_position + hit_normal, up_vector)
	
	# 3. Apply random rotation around the local Z-axis (roll) to break up repetition
	decal.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))
	
	# 4. Add to our tracking pool
	_active_decals.append(decal)
	
	# 5. Enforce the maximum limit
	if _active_decals.size() > max_decals:
		# Explicitly type and cast the popped Variant to satisfy strict typing rules
		var oldest_decal: Node3D = _active_decals.pop_front() as Node3D
		if is_instance_valid(oldest_decal):
			oldest_decal.queue_free()
