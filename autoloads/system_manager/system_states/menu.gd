## Menu State
extends State

var next_state: State


func enter():
	state_machine.parent.get_tree().paused = false


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
