## Stone Choir - Dormant State
extends State
## Silent and motionless until it first spots a player (range + line-of-sight, no
## facing required). Rechecks every tick rather than caching a one-time flag: once it
## transitions to Moving it never returns here except via Gone -> respawn, so the net
## effect is identical to fedex's sticky "_awakened" flag.

var actor: StoneChoir


func enter() -> void:
	actor = state_machine.parent as StoneChoir


func update(_delta: float) -> State:
	actor.freeze_at_current_position()
	if actor.check_awaken():
		return state_machine.states["Moving"]
	return null
