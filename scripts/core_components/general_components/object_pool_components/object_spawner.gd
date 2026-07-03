@icon("uid://3mlg8wmxmykk")
class_name ObjectSpawner
extends Marker2D
## A generic component for spawning or pooling objects.
##
## This node abstracts the creation of objects, allowing a parent
## entity to spawn scenes or retrieve items from the global ObjectPool
## without knowing the underlying implementation details.

# SIGNALS
signal object_spawned(spawned_node: Node) ## Emitted immediately after retrieval/instantiation, before transforms are applied.

# EXPORT VARIABLES
@export_group("Spawning Details")
@export var scene_to_spawn: PackedScene ## The default scene to instantiate if not pooling.
@export var use_pooling: bool = false ## Toggle to use the ObjectPool autoload instead of standard instantiation.
@export var pool_name: String = "" ## The string key used if use_pooling is true.

@export_group("Hierarchy & Transform")
@export var top_level_spawn: bool = true ## If true, spawns as a child of the current scene root to decouple movement.
@export var spawn_target_parent: Node ## Specific parent node override. If empty, falls back to top_level_spawn or direct parent.
@export var match_spawner_transform: bool = true ## Applies this Spawner's global_transform to the spawned object.


# PUBLIC FUNCTIONS
func spawn(override_scene: PackedScene = null, override_pool_name: String = "") -> Node: ## Spawns an object based on configuration or overrides, places it in the tree, and returns it.
	var spawned_node: Node = null
	var actual_pool_name: String = override_pool_name if override_pool_name != "" else pool_name
	var actual_scene: PackedScene = override_scene if override_scene != null else scene_to_spawn
	var is_pooled: bool = false
	
	if use_pooling or actual_pool_name != "":
		if actual_pool_name == "":
			push_error("ObjectSpawner: Pooling enabled but no pool name provided.")
			return null
		spawned_node = ObjectPool.get_item(actual_pool_name)
		is_pooled = true
	else:
		if actual_scene == null:
			push_error("ObjectSpawner: No scene provided to spawn.")
			return null
		spawned_node = actual_scene.instantiate()
		
	if not spawned_node:
		return null
		
	# Emit signal so the parent can inject data or custom resources early
	object_spawned.emit(spawned_node)
	
	# Only parent the object if it's a fresh instantiation
	if not is_pooled:
		_parent_spawned_object(spawned_node)
	
	# Match transforms based on the type of node spawned
	if match_spawner_transform:
		if spawned_node is Node2D:
			spawned_node.global_transform = global_transform
		elif spawned_node is Control:
			spawned_node.global_position = global_position
			spawned_node.rotation = global_rotation
			spawned_node.scale = global_scale
	
	return spawned_node


# PRIVATE FUNCTIONS
func _parent_spawned_object(node: Node) -> void: # Determines where the newly instantiated node should live and adds it to the tree.
	var target: Node = spawn_target_parent
	
	if not target:
		if top_level_spawn:
			target = get_tree().current_scene
		else:
			target = get_parent()
			
	target.add_child(node)
