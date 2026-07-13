## Stone Choir - Observed State
extends State
## Frozen while any player can see any part of it. Deliberately does NOT attempt a
## catch while observed, even if a player is standing well within catch_range -- it
## must stop being watched and return to Moving first, then catch on a later tick.
## This is load-bearing fedex behavior (see the port's regression-test checklist);
## do not "simplify" this by calling try_catch() here.

var actor: StoneChoir


func enter() -> void:
	actor = state_machine.parent as StoneChoir


func update(_delta: float) -> State:
	actor.freeze_at_current_position()
	if not actor.is_seen_by_any_player():
		return state_machine.states["Moving"]
	return null
