class_name TopDownDash
extends Node
## Handles voluntary dash mechanics, including velocity bursts, 
## cooldowns, i-frames, and animation overrides.

# SIGNALS
signal dash_started ## Emitted when the dash begins.
signal dash_ended ## Emitted when the dash finishes.
signal dash_cooldown_finished ## Emitted when the dash is ready to use again.


# EXPORT VARIABLES
@export_group("References")
@export var parent: CharacterBody2D ## The physics body to move.
@export var movement_component: TopDownMovement ## The movement component to temporarily disable.
@export var hit_point_component: HitPointComponent ## Optional: To grant i-frames during the dash.
@export var animator: TopDownAnimator ## Optional: To play a dash animation.

@export_group("Dash Stats")
@export var dash_speed: float = 600.0 ## The speed of the dash burst.
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
func try_dash(direction: Vector2) -> void: ## Attempts to trigger a dash in the given direction.
	if is_dashing or is_on_cooldown or direction == Vector2.ZERO:
		return
		
	if not parent or not movement_component:
		return
		
	_start_dash(direction.normalized())


# PRIVATE FUNCTIONS
func _start_dash(direction: Vector2) -> void:
	is_dashing = true
	movement_component.movement_enabled = false
	
	# Apply dash velocity
	parent.velocity = direction * dash_speed
	
	# Handle optional i-frames [cite: 153]
	if hit_point_component:
		hit_point_component.set_invulnerablility(true, dash_duration)
		
	# Handle optional animation override [cite: 112]
	if animator and use_dash_animation:
		animator.play_animation(dash_anim_name, true)
		
	dash_started.emit()
	
	# Setup Dash Timer
	_dash_timer = get_tree().create_timer(dash_duration, false)
	_dash_timer.timeout.connect(_on_dash_finished)


func _on_dash_finished() -> void:
	is_dashing = false
	movement_component.movement_enabled = true
	
	# Clear animation override [cite: 113]
	if animator:
		animator.reset_animation()
		
	dash_ended.emit()
	_start_cooldown()


func _start_cooldown() -> void:
	is_on_cooldown = true
	_cooldown_timer = get_tree().create_timer(dash_cooldown, false)
	_cooldown_timer.timeout.connect(func():
		is_on_cooldown = false
		dash_cooldown_finished.emit()
	)
