## ReadyToStart State
extends State

var next_state: State
var gameplay_manager: GameplayManager


func enter():
	gameplay_manager = state_machine.parent as GameplayManager


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
