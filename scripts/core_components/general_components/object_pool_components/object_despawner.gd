@icon("uid://dkar117ynfjg3")
class_name ObjectDespawner
extends Node
## A generic component to handle the destruction or pooling of a target node.
##
## Attach this to any scene to provide a standardized way to despawn it.
## It can act on a timer or be triggered manually via the despawn() method.

# EXPORT VARIABLES
@export_group("Target Details")
@export var target_node: Node ## The node to despawn. If left empty, defaults to the parent node.

@export_group("Object Pooling")
@export var use_object_pool: bool = false
@export var pool_name: String = "" ## If provided, returns the target to this pool. If empty, calls queue_free().

@export_group("Auto Despawn")
@export var auto_despawn: bool = false
@export var auto_despawn_time: float = 0.0 ## If greater than 0, automatically despawns after this many seconds.

# PRIVATE VARIABLES
var _timer: Timer


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not target_node:
		target_node = get_parent()
		
	if auto_despawn and auto_despawn_time > 0.0:
		_start_timer(auto_despawn_time)


# PUBLIC FUNCTIONS
func initialize(dynamic_pool_name: String) -> void: ## Updates the pool name dynamically. Use if the spawner assigns pool name at runtime.
	pool_name = dynamic_pool_name


func despawn() -> void: ## Executes the despawn logic immediately
	if not is_instance_valid(target_node):
		return
		
	# Cancel the timer if it's running so it doesn't try to despawn twice
	if _timer and not _timer.is_stopped():
		_timer.stop()
		
	if use_object_pool and pool_name != "":
		ObjectPool.return_item(pool_name, target_node)
	else:
		target_node.queue_free()


# PRIVATE FUNCTIONS
func _start_timer(duration: float) -> void: # Handles the creation and connection of the auto-despawn timer
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(despawn)
		add_child(_timer)
		
	_timer.start(duration)
