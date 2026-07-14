## Enemy State - Observed (sight-based enemies only, e.g. Stone Choir)
extends State
## Frozen while any player can see it. Deliberately does NOT attempt a catch
## here, even if a player is standing well within catch_range -- it must stop
## being watched and return to Moving first, then catch on a later tick. This
## is load-bearing behavior ported from the original design; do not
## "simplify" this by calling try_catch() here.

# PUBLIC VARIABLES
var enemy: Enemy
var senses: EnemySenses
var movement: EnemyMovementController

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	senses = enemy.enemy_senses
	movement = enemy.enemy_movement_controller


func update(delta: float) -> State:
	movement.stop(delta)
	if not senses.is_seen_by_any_player():
		return state_machine.states.get("Moving")
	return null
