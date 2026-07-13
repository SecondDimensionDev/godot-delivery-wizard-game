## Listener - Dormant State
extends State
## Motionless and silent until accumulated attention crosses agitate_threshold (straight
## to Moving if it's already past chase_threshold with a heard spot -- a single loud jolt
## can skip Agitated entirely, matching fedex's original hysteresis table).

var actor: Listener


func enter() -> void:
	actor = state_machine.parent as Listener


func update(_delta: float) -> State:
	if actor.should_commit_to_moving():
		return state_machine.states["Moving"]
	if actor.should_wake_agitated():
		return state_machine.states["Agitated"]
	return null
