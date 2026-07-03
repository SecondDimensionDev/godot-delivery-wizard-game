## System Loading State
extends State

# PUBLIC VARIABLES
var next_state: State

# PRIVATE VARIABLES
var _target_scene_path: String = ""
var _target_state: State
var _target_type: LoadingScreen.LevelType
var _transition_in: bool
var _transition_out: bool
var _wait_for_setup: bool = false


# PUBLIC FUNCTIONS
func setup_transition(target_state: State, target_scene_path: String, target_scene_type: LoadingScreen.LevelType, transition_in: bool, transition_out:bool, wait_for_setup: bool) -> void: ## Configures the next load operation.
	_target_scene_path = target_scene_path
	_target_state = target_state
	_target_type = target_scene_type
	_transition_in = transition_in
	_transition_out = transition_out
	_wait_for_setup = wait_for_setup


# VIRTUAL FUNCTIONS
func enter():
	# Connect to the autoload signal
	if not LoadingScreen.scene_loaded.is_connected(_on_scene_loaded):
		LoadingScreen.scene_loaded.connect(_on_scene_loaded)
	
	EventBus.system_state.loading_started.emit()
	
	# Trigger the load via the autoload
	LoadingScreen.change_level(_target_scene_path, _target_type, _transition_in, _transition_out, _wait_for_setup)


func exit():
# Clean up signals to prevent memory leaks or unwanted calls
	if LoadingScreen.scene_loaded.is_connected(_on_scene_loaded):
		LoadingScreen.scene_loaded.disconnect(_on_scene_loaded)
	
	EventBus.system_state.loading_finished.emit()
	
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if next_state:
		return next_state
	
	return null


# PRIVATE FUNCTIONS
func _on_scene_loaded() -> void:
	state_machine.change_state(_target_state)
