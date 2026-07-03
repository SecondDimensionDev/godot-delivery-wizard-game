@icon("uid://cqr1itkxvpij8")
class_name BaseLoadingScreen
extends CanvasLayer
## A global manager that handles asynchronous scene loading, transitions, and loading UI.
##
## This system completely decouples the visual transition (fade in/out) and the 
## loading screen content (spinners, tips) from the multi-threaded resource loading logic.
## This is extended for the LoadingScreen autoload, where any game-specific logic can be added.

# SIGNALS
signal scene_loaded ## Emitted when the background thread has finished loading the resource
signal transition_complete ## Emitted when the new scene is active and the transition out has finished

# ENUMS
enum LevelType {
	MENU,       ## Fast load, no content shown, 0.0s delay
	SIMPLE_2D,  ## Minor load, short minimum delay
	COMPLEX_2D, ## Moderate load, medium minimum delay
	COMPLEX_3D     ## Heavy load, long minimum delay
}

# EXPORT VARIABLES
@export_group("Transitions")
@export var fade_animation: AnimationPlayer
@export var fade_texture: ColorRect

@export_group("Screen Content")
@export var loading_label: Label
@export var loading_icon: TextureRect
@export var content_fade_duration: float = 0.3

@export_group("Loading Config")
@export var delay_simple_2d: float = 0.8
@export var delay_complex_2d: float = 1.0
@export var delay_complex_3d: float = 1.5
@export var use_sub_threads: bool = false

# PRIVATE VARIABLES
var _scene_path: String = ""
var _loaded_scene: PackedScene
var _level_type: LevelType
var _transition_out_active: bool
var _minimum_delay_timer: Timer
var _content_tween: Tween
var _wait_for_setup: bool = false


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	hide()
	set_process(false)
	
	if loading_label:
		loading_label.hide()
	if loading_icon:
		loading_icon.hide()
		
	_minimum_delay_timer = Timer.new()
	_minimum_delay_timer.one_shot = true
	add_child(_minimum_delay_timer)


func _process(_delta: float) -> void:
	var progress_array: Array = []
	var loading_status = ResourceLoader.load_threaded_get_status(_scene_path, progress_array)
	
	match loading_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_on_progress(progress_array[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_on_scene_loaded()
		ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			push_error("LoadingScreen: Scene Load Failed at path: ", _scene_path)


# PUBLIC FUNCTIONS
func change_level(path: String, type: LevelType = LevelType.MENU, transition_in: bool = true, transition_out: bool = true, wait_for_setup: bool = false) -> void: ## Starts the full loading sequence
	_scene_path = path
	_level_type = type
	_transition_out_active = transition_out
	_wait_for_setup = wait_for_setup
	
	show()
	
	# 1. Transition In
	if transition_in:
		await _play_transition_in()
	else:
		if fade_texture:
			fade_texture.modulate.a = 1.0
	
	# 2. Show Content (Skip if Menu)
	if _level_type != LevelType.MENU:
		await _show_loading_content()
		
	# 3. Start Loading Data
	_start_loading()


# PRIVATE FUNCTIONS
func _start_loading() -> void: # Requests the thread and starts the delay timer
	ResourceLoader.load_threaded_request(_scene_path, "", use_sub_threads)
	
	match _level_type:
		LevelType.SIMPLE_2D:
			_minimum_delay_timer.start(delay_simple_2d)
		LevelType.COMPLEX_2D:
			_minimum_delay_timer.start(delay_complex_2d)
		LevelType.COMPLEX_3D:
			_minimum_delay_timer.start(delay_complex_3d)
			
	set_process(true)


func _on_progress(_progress: float) -> void: # Hook for updating progress bars or % text
	# loading progress is a float between 0.0 and 1.0
	# use progress argument to update a % number later if needed
	pass


func _on_scene_loaded() -> void: # Handles logic when data is fully in memory
	_loaded_scene = ResourceLoader.load_threaded_get(_scene_path)
	
	# Wait for the minimum delay if it hasn't finished yet
	if _level_type != LevelType.MENU and _minimum_delay_timer.time_left > 0:
		await _minimum_delay_timer.timeout
		
	_change_scene()


func _change_scene() -> void: # Swaps the scene tree and finishes the sequence
	get_tree().change_scene_to_packed(_loaded_scene)
	
	if _wait_for_setup:
		await EventBus.system_state.scene_setup_complete
	
	# Hide the loading content before we fade out
	if _level_type != LevelType.MENU:
		await _hide_loading_content()
		
	scene_loaded.emit()
	
	if _transition_out_active:
		await _play_transition_out()
		
	_finish_and_cleanup()


func _finish_and_cleanup() -> void: # Resets state and hides the canvas layer
	hide()
	_scene_path = ""
	_loaded_scene = null
	transition_complete.emit()


# --- MODULAR UI HOOKS ---

func _play_transition_in() -> void: # Plays the intro screen wipe/fade
	if fade_animation:
		fade_animation.play("FadeIn")
		await fade_animation.animation_finished


func _play_transition_out() -> void: # Plays the outro screen wipe/fade
	if fade_animation:
		fade_animation.play("FadeOut")
		await fade_animation.animation_finished


func _show_loading_content() -> void: # Displays and fades in UI content
	if _content_tween and _content_tween.is_valid():
		_content_tween.kill()
		
	_content_tween = create_tween().set_parallel(true)
	var has_nodes_to_tween: bool = false
	
	if loading_label:
		loading_label.modulate.a = 0.0
		loading_label.show()
		_content_tween.tween_property(loading_label, "modulate:a", 1.0, content_fade_duration)
		has_nodes_to_tween = true
		
	if loading_icon:
		loading_icon.modulate.a = 0.0
		loading_icon.show()
		_content_tween.tween_property(loading_icon, "modulate:a", 1.0, content_fade_duration)
		has_nodes_to_tween = true
		
	if has_nodes_to_tween:
		await _content_tween.finished


func _hide_loading_content() -> void: # Fades out and hides the UI content
	if _content_tween and _content_tween.is_valid():
		_content_tween.kill()
		
	_content_tween = create_tween().set_parallel(true)
	var has_nodes_to_tween: bool = false
	
	if loading_label:
		_content_tween.tween_property(loading_label, "modulate:a", 0.0, content_fade_duration)
		has_nodes_to_tween = true
	if loading_icon:
		_content_tween.tween_property(loading_icon, "modulate:a", 0.0, content_fade_duration)
		has_nodes_to_tween = true
		
	if has_nodes_to_tween:
		# Chain a callback to actually hide the nodes once the fade reaches 0.0
		_content_tween.chain().tween_callback(func():
			if loading_label: loading_label.hide()
			if loading_icon: loading_icon.hide()
		)
		await _content_tween.finished
