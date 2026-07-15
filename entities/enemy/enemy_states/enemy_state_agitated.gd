## Enemy State - Agitated (hearing-based enemies only, e.g. Listener)
extends State
## Heard something, no lock yet: turns to face the last heard spot while
## attention builds toward chase_threshold or drains back to Dormant.

# PUBLIC VARIABLES
var enemy: Enemy
var senses: EnemySenses

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	senses = enemy.enemy_senses


func update(delta: float) -> State:
	if senses.should_commit_to_moving():
		return state_machine.states.get("Moving")
	if senses.should_calm_to_dormant():
		return state_machine.states.get("Dormant")
	enemy.enemy_rotation_controller.face_point(senses.heard_position, delta)
	return null
