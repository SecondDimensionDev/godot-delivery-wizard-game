@icon("uid://qlgudf3nt0ig")
class_name LocalPoolSetup
extends Node
## Dropped into a level to automatically configure the global ObjectPool via the Inspector.

@export_group("Pool Configuration")
@export var pools_to_create: Array[PoolConfig]


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	for config in pools_to_create:
		if config.pool_name != "" and config.scene != null:
			ObjectPool.create_pool(config.pool_name, config.scene, config.min_size)
