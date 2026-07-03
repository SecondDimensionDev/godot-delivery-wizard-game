## HubShop State
extends State

var next_state: State
var hub_manager: HubManager

func enter():
	hub_manager = state_machine.parent as HubManager
	SessionManager.save_run()
	next_state = state_machine.states["Map"]


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
