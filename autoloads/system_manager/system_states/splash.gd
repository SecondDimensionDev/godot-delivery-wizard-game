## Splash State
extends State

var next_state: State


func enter():
	EventBus.system_state.start_splash_process.emit()


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
