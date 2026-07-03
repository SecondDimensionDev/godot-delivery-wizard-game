class_name TopDownDash3D
extends Node
## Handles voluntary dash mechanics in 3D, including velocity bursts,
## cooldowns, i-frames, and animation overrides.

# SIGNALS
signal dash_started ## Emitted when the dash begins.
signal dash_ended ## Emitted when the dash finishes.
signal dash_cooldown_finished ## Emitted when the dash is ready to use again.

# EXPORT VARIABLES
@export_group("References")
@export var parent: CharacterBody3D ## The physics body to move.
@export var movement_component: TopDownMovement3D ## The movement component to temporarily disable.
@export var hit_point_component: HitPointComponent ## Optional: To grant i-frames during the dash.
@export var animator: AnimationPlayer ## Optional: To play a dash animation.

@export_group("Dash Stats")
@export var dash_speed: float = 25.0 ## The speed of the dash burst.
@export var dash_duration: float = 0.2 ## How long the dash lasts.
@export var dash_cooldown: float = 1.0 ## Time before the dash can be used again.

@export_group("Dash Animation")
@export var use_dash_animation: bool = false
@export var dash_anim_name: String = "dash" ## The animation string to send to the animator.

# PUBLIC VARIABLES
var is_dashing: bool = false
var is_on_cooldown: bool = false

# PRIVATE VARIABLES
var _dash_timer: SceneTreeTimer
var _cooldown_timer: SceneTreeTimer

# PUBLIC FUNCTIONS
func try_dash(direction: Vector3) -> void:
	## Attempts to trigger a dash in the given direction.
	if is_dashing or is_on_cooldown or direction == Vector3.ZERO:
		return
		
	if not parent or not movement_component:
		return
		
	_start_dash(direction.normalized())

# PRIVATE FUNCTIONS
func _start_dash(direction: Vector3) -> void:
	is_dashing = true
	movement_component.movement_enabled = false
	
	# Preserve the Y velocity so gravity still applies properly
	var current_y = parent.velocity.y
	parent.velocity = direction * dash_speed
	parent.velocity.y = current_y
	
	# Handle optional i-frames
	if hit_point_component:
		hit_point_component.set_invulnerablility(true, dash_duration)
		
	# Handle optional animation
	if animator and use_dash_animation and animator.has_animation(dash_anim_name):
		animator.play(dash_anim_name)
		
	dash_started.emit()
	
	# Setup Dash Timer
	_dash_timer = get_tree().create_timer(dash_duration, false)
	_dash_timer.timeout.connect(_on_dash_finished)

func _on_dash_finished() -> void:
	is_dashing = false
	movement_component.movement_enabled = true
	
	dash_ended.emit()
	_start_cooldown()

func _start_cooldown() -> void:
	is_on_cooldown = true
	_cooldown_timer = get_tree().create_timer(dash_cooldown, false)
	_cooldown_timer.timeout.connect(func():
		is_on_cooldown = false
		dash_cooldown_finished.emit()
	)
