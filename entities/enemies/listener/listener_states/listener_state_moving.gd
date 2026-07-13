## Listener - Moving State
extends State
## Committed: walks toward the last heard SPOT (not the mover -- it is blind). Catches
## take priority over movement each tick; attention draining below
## chase_threshold * CALM_FRACTION demotes back to Agitated.

var actor: Listener


func enter() -> void:
	actor = state_machine.parent as Listener


func update(delta: float) -> State:
	if actor.should_demote_to_agitated():
		return state_machine.states["Agitated"]
	if actor.try_catch():
		return state_machine.states["Attacking"]
	actor.advance(delta)
	return null
