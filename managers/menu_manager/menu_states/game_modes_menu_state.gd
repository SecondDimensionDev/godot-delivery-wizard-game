## GameModesMenu State
extends State

var next_state: State
var menu_manager: MenuManager

func enter():
	menu_manager = state_machine.parent as MenuManager
	
	EventBus.menu_navigation.request_go_back.connect(_request_go_back)
	
	menu_manager.game_modes_scene.show()


func exit():
	EventBus.menu_navigation.request_go_back.disconnect(_request_go_back)
	
	menu_manager.game_modes_scene.hide()
	
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


func _start_game() -> void:
	SessionManager.start_new_run()
	SystemManager.request_system_state_and_scene_change("Gameplay", Directory.CORE_LEVELS.first_level, LoadingScreen.LevelType.SIMPLE_2D, true, true)


func _continue_game() -> void:
	SystemManager.request_system_state_and_scene_change("Gameplay", Directory.CORE_LEVELS.first_level, LoadingScreen.LevelType.SIMPLE_2D, true, true)
