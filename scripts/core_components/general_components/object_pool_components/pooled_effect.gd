class_name PooledEffect extends Node2D
## Automatically plays and returns a visual effect to the ObjectPool when finished.
##
## Attach this to the root node of your impact particle scenes.
## It automatically detects if the effect is a particle system or an animation.

# EXPORT VARIABLES
@export var effect_node: Node ## The node that plays the effect. If left empty, defaults to self.

# PRIVATE VARIABLES
var _pool_name: String = ""


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not effect_node:
		effect_node = self
		
	# Dynamically connect to the correct completion signal based on the node type
	if effect_node.has_signal("finished"): # For GPUParticles2D / CPUParticles2D
		effect_node.finished.connect(_on_effect_finished)
	elif effect_node.has_signal("animation_finished"): # For AnimatedSprite2D
		effect_node.animation_finished.connect(_on_effect_finished)


# PUBLIC FUNCTIONS
func initialize(pool_name: String) -> void: ## Stores the pool name and starts the visual effect.
	_pool_name = pool_name
	
	if effect_node is GPUParticles2D or effect_node is CPUParticles2D:
		effect_node.restart() # Restart ensures the particle completely resets from the pool
		effect_node.emitting = true
	elif effect_node is AnimatedSprite2D:
		effect_node.stop()
		effect_node.play()


# PRIVATE FUNCTIONS
func _on_effect_finished() -> void: # Returns the item to the pool or deletes it if no pool is assigned.
	if _pool_name == "":
		queue_free()
	else:
		ObjectPool.return_item(_pool_name, self)
