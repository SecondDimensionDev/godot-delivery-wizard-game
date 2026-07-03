class_name PoolConfig
extends Resource
## A configuration resource used to define an ObjectPool setup.

@export var pool_name: String = "" ## The string key used to retrieve this item.
@export var scene: PackedScene ## The PackedScene to instantiate.
@export var min_size: int = 10 ## The starting size of the pool.
