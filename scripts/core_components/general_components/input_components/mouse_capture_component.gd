class_name MouseCaptureComponent
extends Node
## Handles locking and freeing the mouse cursor.
##
## Can automatically capture the mouse on start. Listens for a specific
## input action (like 'ui_cancel') to toggle the state. Broadcasts signals
## so UI and Pause systems can react.

# EXPORT VARIABLES
@export var capture_on_ready: bool = true ## If true, locks the mouse as soon as the scene loads.
@export var sync_to_pause_state: bool = true ## If true, mouse will release on pause and capture on resume
@export var toggle_with_input_action: bool = false ## Determines if a mapped input action will capture and release the mouse
@export var toggle_action_name: String = "ui_cancel" ## The InputMap action used to release/capture the mouse.


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if capture_on_ready:
		capture()
	if sync_to_pause_state:
		EventBus.system_state.game_paused.connect(release)
		EventBus.system_state.game_resumed.connect(capture)


func _unhandled_input(event: InputEvent) -> void:
	if toggle_with_input_action:
		if event.is_action_pressed(toggle_action_name):
			if is_captured():
				release()
			else:
				capture()


# PUBLIC FUNCTIONS
func capture() -> void: ## Locks the mouse cursor to the center of the window and hides it.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	EventBus.system_state.mouse_captured.emit()


func release() -> void: ## Frees the mouse cursor and makes it visible.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	EventBus.system_state.mouse_released.emit()


func is_captured() -> bool: ## Returns true if the mouse is currently locked.
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
