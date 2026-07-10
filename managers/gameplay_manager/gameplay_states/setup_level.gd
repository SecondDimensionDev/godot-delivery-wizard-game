## SetupLevel State
extends State

var next_state: State
var gameplay_manager: GameplayManager

var _setup_complete: bool = false

func enter():
	gameplay_manager = state_machine.parent as GameplayManager
	
	_first_time_setup.call_deferred()


func exit():
	
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if _setup_complete:
		next_state = state_machine.states["Play"]
	
	if next_state:
		return next_state
	
	return null



func _first_time_setup() -> void:
	EventBus.system_state.scene_setup_complete.emit()
	_setup_complete = true
