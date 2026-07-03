@icon("uid://b74xfijkgxm56")
class_name TopDownKnockback3D
extends Node
## Applies a sudden physics impulse to a CharacterBody3D.
##
## Temporarily disables the linked [TopDownMovement3D] to prevent interference.
## Injects a velocity spike into the target body, optionally bumping them
## slightly into the air, before naturally decelerating via friction.

# SIGNALS
signal knockback_started ## Emitted when the entity loses control and is knocked back.
signal knockback_ended ## Emitted when control is restored.

# EXPORT VARIABLES
@export_group("References")
@export var parent: CharacterBody3D ## The physics body to push.
@export var movement_component: TopDownMovement3D ## The movement component to temporarily disable.

# PRIVATE VARIABLES
var _knockback_timer: SceneTreeTimer

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not parent:
		push_warning("TopDownKnockback3D is missing a reference to a CharacterBody3D.")
	if not movement_component:
		push_warning("TopDownKnockback3D is missing a reference to a TopDownMovement3D component.")

# PUBLIC FUNCTIONS
func apply_knockback(direction: Vector3, force: float, duration: float, y_bump: float = 0.0) -> void:
	## Applies a sudden velocity spike and disables movement for the duration.
	## Provide a positive y_bump to knock the entity slightly into the air.
	if not parent or not movement_component:
		return
		
	# Disable standard movement inputs
	movement_component.movement_enabled = false
	
	var impulse := direction.normalized() * force
	
	# Apply the vertical bump, or preserve existing gravity if 0
	if y_bump > 0.0:
		impulse.y = y_bump
	else:
		impulse.y = parent.velocity.y
		
	# Apply the raw impulse directly to the physics body
	parent.velocity = impulse
	knockback_started.emit()
	
	# Handle the stun duration
	if _knockback_timer:
		_knockback_timer.timeout.disconnect(_on_knockback_finished)
		
	_knockback_timer = get_tree().create_timer(duration, false)
	_knockback_timer.timeout.connect(_on_knockback_finished)

# PRIVATE FUNCTIONS
func _on_knockback_finished() -> void:
	# Restores movement control to the entity.
	if movement_component:
		movement_component.movement_enabled = true
	knockback_ended.emit()
