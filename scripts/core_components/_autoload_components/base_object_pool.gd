class_name BaseObjectPool
extends Node
## An efficient object pooling system for managing and reusing Nodes.
##
## This autoload prevents performance spikes by reusing existing nodes instead 
## of frequently instantiating and freeing them. It manages "dormant" nodes 
## by disabling their processing and hiding them within a dedicated container.
## This is extended for the autoload, where any game-specific logic can be added.


# PRIVATE VARIABLES
var _pools: Dictionary = {} # Stores pool data: { "name": { "scene": PackedScene, "items": Array[Node] } }.


# VIRTUAL BUILT-IN FUNCTIONS
func _ready() -> void:
	EventBus.system_state.loading_started.connect(clear_all_pools)


# PUBLIC FUNCTIONS
func create_pool(pool_name: String, scene: PackedScene, min_size: int = 10) -> void: ## Initializes or updates a pool's capacity.
	# Check pool exists and update it if required
	if _pools.has(pool_name):
		var current_size = _pools[pool_name]["items"].size()
		
		if current_size < min_size:
			var amount_to_add = min_size - current_size
			for i in range(amount_to_add):
				_add_new_item_to_pool(pool_name, scene)
		
		return
	
	# Create pool if it doesn't exist
	_pools[pool_name] = {
		"scene": scene,
		"items": []
	}
	
	for i in range(min_size):
		_add_new_item_to_pool(pool_name, scene)


func get_item(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("ObjectPool: No pool named '%s'." % pool_name)
		return null
	
	var items: Array = _pools[pool_name]["items"]
	var scene: PackedScene = _pools[pool_name]["scene"]
	
	# Loop backwards so we can safely remove dead items as we find them
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		
		# The Safety Net: Check if the node was freed by Godot
		if not is_instance_valid(item):
			items.remove_at(i)
			continue
			
		if item.process_mode == Node.PROCESS_MODE_DISABLED and not item.visible:
			_wake_item(item)
			return item
	
	# Dynamically expand the pool
	var new_item = _add_new_item_to_pool(pool_name, scene)
	_wake_item(new_item)
	return new_item


func return_item(pool_name: String, item: Node) -> void: ## Deactivates an item and returns it to the dormant container.
	if not _pools.has(pool_name):
		push_error("ObjectPool: No pool named '%s'." % pool_name)
		item.queue_free() # Fallback so we don't leak memory
		return
	
	_sleep_item(item)


func clear_all_pools() -> void: ## Safely destroys all pooled objects and clears the dictionary.
	for pool_name in _pools.keys():
		var items = _pools[pool_name]["items"]
		for item in items:
			if is_instance_valid(item):
				item.queue_free()
	
	_pools.clear()


# PRIVATE FUNCTIONS
func _add_new_item_to_pool(pool_name: String, scene: PackedScene) -> Node: 
	var item = scene.instantiate() 
	_sleep_item(item) 
	add_child(item) # Add directly to the Autoload
	_pools[pool_name]["items"].append(item) 
	return item


func _sleep_item(item: Node) -> void:
	item.hide()
	item.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED) # Defer the state change


func _wake_item(item: Node) -> void:
	item.show()
	item.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT) # Defer the state change
