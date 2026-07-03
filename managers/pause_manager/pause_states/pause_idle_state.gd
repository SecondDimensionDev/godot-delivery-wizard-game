## Idle State
extends State

var next_state: State
var pause_manager: PauseManager

func enter():
	pause_manager = state_machine.parent as PauseManager


func exit():
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if next_state:
		return next_state
	
	return null
