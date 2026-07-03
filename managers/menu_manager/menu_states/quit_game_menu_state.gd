## ExitGameMenu State
extends State

var next_state: State
var menu_manager: MenuManager

func enter():
	menu_manager = state_machine.parent as MenuManager
	
	EventBus.menu_navigation.confirm_quit.connect(_confirm_quit)
	EventBus.menu_navigation.request_go_back.connect(_request_go_back)
	
	menu_manager.quit_game_scene.show()


func exit():
	EventBus.menu_navigation.confirm_quit.disconnect(_confirm_quit)
	EventBus.menu_navigation.request_go_back.disconnect(_request_go_back)
	
	menu_manager.quit_game_scene.hide()
	
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


func _confirm_quit() -> void:
	menu_manager.get_tree().quit()
