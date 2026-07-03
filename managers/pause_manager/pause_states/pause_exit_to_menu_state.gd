## GameModesMenu State
extends State

var next_state: State
var pause_manager: PauseManager

func enter():
	pause_manager = state_machine.parent as PauseManager
	
	EventBus.menu_navigation.confirm_exit.connect(_exit_to_menu)
	EventBus.menu_navigation.request_go_back.connect(_request_go_back)
	
	pause_manager.exit_to_menu_scene.show()


func exit():
	EventBus.menu_navigation.confirm_exit.disconnect(_exit_to_menu)
	EventBus.menu_navigation.request_go_back.disconnect(_request_go_back)
	
	pause_manager.exit_to_menu_scene.hide()
	
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


func _exit_to_menu() -> void:
	SystemManager.request_system_state_and_scene_change("Menu", Directory.CORE_LEVELS.main_menu, LoadingScreen.LevelType.MENU, true, true)
