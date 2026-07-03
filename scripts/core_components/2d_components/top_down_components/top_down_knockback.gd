@icon("uid://b74xfijkgxm56")
class_name TopDownKnockback
extends Node
## Applies a sudden physics impulse to a CharacterBody2D.
##
## This component temporarily disables the linked [TopDownMovement]
## to prevent AI or player inputs from interfering. It injects a velocity
## spike into the target body, allowing the [TopDownMovement]'s natural
## friction to smoothly decelerate the entity over the knockback duration.

# SIGNALS
signal knockback_started ## Emitted when the entity loses control and is knocked back.
signal knockback_ended ## Emitted when control is restored.

# EXPORT VARIABLES
@export_group("References")
@export var parent: CharacterBody2D ## The physics body to push.
@export var movement_component: TopDownMovement ## The movement component to temporarily disable.


# PRIVATE VARIABLES
var _knockback_timer: SceneTreeTimer


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not parent:
		push_warning("KnockbackComponent is missing a reference to a CharacterBody2D.")
	if not movement_component:
		push_warning("KnockbackComponent is missing a reference to a TopDownMovement component.")


# PUBLIC FUNCTIONS
func apply_knockback(direction: Vector2, force: float, duration: float) -> void: ## Applies a sudden velocity spike and disables movement for the duration.
	if not parent or not movement_component:
		return
		
	# Disable standard movement inputs
	movement_component.movement_enabled = false
	
	# Apply the raw impulse directly to the physics body
	parent.velocity = direction.normalized() * force
	knockback_started.emit()
	
	# Handle the stun duration
	if _knockback_timer:
		_knockback_timer.timeout.disconnect(_on_knockback_finished)
		
	_knockback_timer = get_tree().create_timer(duration, false)
	_knockback_timer.timeout.connect(_on_knockback_finished)


# PRIVATE FUNCTIONS
func _on_knockback_finished() -> void: # Restores movement control to the entity.
	if movement_component:
		movement_component.movement_enabled = true
	knockback_ended.emit()
