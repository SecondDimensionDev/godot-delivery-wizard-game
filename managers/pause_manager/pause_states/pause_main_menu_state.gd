## MainMenu State
extends State

var next_state: State
var pause_manager: PauseManager

func enter():
	pause_manager = state_machine.parent as PauseManager
	
	EventBus.menu_navigation.request_goto_options.connect(_request_options)
	EventBus.menu_navigation.request_goto_credits.connect(_request_credits)
	EventBus.menu_navigation.request_goto_help.connect(_request_help)
	EventBus.menu_navigation.request_goto_quit_confirmation.connect(_request_quit_game)
	EventBus.menu_navigation.request_goto_exit_confirmation.connect(_request_exit_to_menu)
	
	pause_manager.main_menu_scene.show()


func exit():
	EventBus.menu_navigation.request_goto_options.disconnect(_request_options)
	EventBus.menu_navigation.request_goto_credits.disconnect(_request_credits)
	EventBus.menu_navigation.request_goto_help.disconnect(_request_help)
	EventBus.menu_navigation.request_goto_quit_confirmation.disconnect(_request_quit_game)
	EventBus.menu_navigation.request_goto_exit_confirmation.disconnect(_request_exit_to_menu)
	
	pause_manager.main_menu_scene.hide()
	
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if next_state:
		return next_state
	
	return null


func _request_options() -> void:
	next_state = state_machine.states["Options"]


func _request_credits() -> void:
	next_state = state_machine.states["Credits"]


func _request_help() -> void:
	next_state = state_machine.states["Help"]


func _request_quit_game() -> void:
	next_state = state_machine.states["QuitGame"]


func _request_exit_to_menu() -> void:
	next_state = state_machine.states["ExitMenu"]
