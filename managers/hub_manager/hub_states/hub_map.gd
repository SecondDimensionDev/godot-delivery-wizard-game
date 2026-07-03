## HubMap State
extends State

var next_state: State
var hub_manager: HubManager


func enter():
	hub_manager = state_machine.parent as HubManager
	var current_id = hub_manager.map_manager.current_player_node_id
	if current_id == "":
		return
	
	var location_node = hub_manager.map_display.get_location_instance_by_grid_string(current_id)
	hub_manager.grid_camera.request_instant_move(location_node.global_position)


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
