## Listener - Attacking State
extends State
## One-shot catch lunge. Holds its own linger timer -- states are instantiated once and
## reused for the node's lifetime (see StateMachine._ready), so a per-state member is safe.

var actor: Listener
var _end_ms := 0


func enter() -> void:
	actor = state_machine.parent as Listener
	actor.sync_position()
	_end_ms = Time.get_ticks_msec() + Listener.ATTACK_LINGER_MS


func update(_delta: float) -> State:
	if Time.get_ticks_msec() >= _end_ms:
		return state_machine.states["Gone"]
	return null
