## Listener - Agitated State
extends State
## Heard something, no lock yet: turns to face the last heard spot while attention
## builds toward chase_threshold or drains back below agitate_threshold * CALM_FRACTION.

var actor: Listener


func enter() -> void:
	actor = state_machine.parent as Listener


func update(delta: float) -> State:
	if actor.should_commit_to_moving():
		return state_machine.states["Moving"]
	if actor.should_calm_to_dormant():
		return state_machine.states["Dormant"]
	actor.face_toward_heard(delta)
	return null
