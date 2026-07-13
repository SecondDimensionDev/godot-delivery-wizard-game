## ReadyToStart State
extends State

var next_state: State
var gameplay_manager: GameplayManager


func enter():
	gameplay_manager = state_machine.parent as GameplayManager
	# Generic hook, not level-specific logic: if this level happens to have a sibling
	# DeliveryEconomy (cargo/job levels do; others simply don't), tell it play has
	# started. Mirrors SetupLevel's own call into gameplay_manager.multiplayer_manager.
	var economy := gameplay_manager.get_node_or_null("../DeliveryEconomy") as DeliveryEconomy
	if economy:
		economy.begin_play()


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
