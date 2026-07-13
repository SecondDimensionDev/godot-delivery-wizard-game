## Stone Choir - Moving State
extends State
## Advances toward the nearest player by walking distance while unseen. Freezes to
## Observed the instant any player sees any part of it; catches take priority over
## movement each tick.

var actor: StoneChoir


func enter() -> void:
	actor = state_machine.parent as StoneChoir


func update(delta: float) -> State:
	if actor.is_seen_by_any_player():
		actor.freeze_at_current_position()
		return state_machine.states["Observed"]
	if actor.try_catch():
		return state_machine.states["Gone"]
	actor.advance(delta)
	return null
