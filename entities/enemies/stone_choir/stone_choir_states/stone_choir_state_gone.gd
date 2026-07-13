## Stone Choir - Gone State
extends State
## Vanished after a catch. Waits respawn_delay_ms, then resets to the spawn pose and
## returns to Dormant. Holds its own timer -- states are instantiated once and reused
## for the node's lifetime (see StateMachine._ready), so a per-state member is safe.

var actor: StoneChoir
var _reappear_ms := 0


func enter() -> void:
	actor = state_machine.parent as StoneChoir
	_reappear_ms = Time.get_ticks_msec() + actor.respawn_delay_ms


func update(_delta: float) -> State:
	if Time.get_ticks_msec() >= _reappear_ms:
		actor.respawn()
		return state_machine.states["Dormant"]
	return null
