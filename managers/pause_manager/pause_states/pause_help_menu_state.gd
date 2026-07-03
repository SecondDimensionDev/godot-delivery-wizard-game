## HelpMenu State
extends State

var next_state: State
var pause_manager: PauseManager

func enter():
	pause_manager = state_machine.parent as PauseManager
	
	EventBus.menu_navigation.request_go_back.connect(_request_go_back)
	
	pause_manager.help_scene.show()


func exit():
	EventBus.menu_navigation.request_go_back.disconnect(_request_go_back)
	
	pause_manager.help_scene.hide()
	
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if next_state:
		return next_state
	
	return null


func _request_go_back() -> void:
	next_state = state_machine.states["MainMenu"]
