class_name BaseTimescaleManager
extends Node
## Global manager for game speed, pausing, and time-based effects.
##
## The TimescaleManager should be set as a Global Autoload. It provides
## standardized methods for pausing the game via the [SceneTree], manipulating 
## the [member Engine.time_scale] with smooth transitions, and triggering 
## 'hit-stop' effects for combat feedback. This base class is used to power the autoload,
## it can be extended to add game-specific logic


# PUBLIC VARIABLES
var default_time_scale: float = 1.0 ## The baseline timescale for the project.

# PRIVATE VARIABLES
var _current_tween: Tween # Internal reference to the active timescale transition.


# PUBLIC FUNCTIONS
func pause_game() -> void: ## Pauses the SceneTree and notifies the EventBus.
	get_tree().paused = true
	EventBus.system_state.game_paused.emit()


func resume_game() -> void: ## Resumes the SceneTree and notifies the EventBus.
	get_tree().paused = false
	EventBus.system_state.game_resumed.emit()


func set_time_scale(target_scale: float, duration_in_real_seconds: float = 0.5) -> void: ## Smoothly transitions the engine timescale to a target value.
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.set_ignore_time_scale(true) 
	
	_current_tween.tween_property(Engine, "time_scale", target_scale, duration_in_real_seconds)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func trigger_hit_stop(duration_in_real_seconds: float = 0.1, stop_scale: float = 0.01) -> void: ## Momentarily stops time to provide impact feedback.
	var previous_scale = Engine.time_scale
	
	Engine.time_scale = stop_scale
	
	await get_tree().create_timer(duration_in_real_seconds, false, false, true).timeout
	
	if is_equal_approx(Engine.time_scale, stop_scale):
		Engine.time_scale = previous_scale


func reset_time(duration: float = 0.5) -> void: ## Returns the engine timescale to the default value.
	set_time_scale(default_time_scale, duration)
