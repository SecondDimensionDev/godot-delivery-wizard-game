## Enemy State - Dormant
extends State
## Motionless and silent until EnemySenses reports something worth reacting
## to. Branches on behaviour_data so one script serves both a hearing-based
## enemy (Listener) and a sight-based one (Stone Choir).

# PUBLIC VARIABLES
var enemy: Enemy
var senses: EnemySenses

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	senses = enemy.enemy_senses


func update(_delta: float) -> State:
	if enemy.behaviour_data.use_hearing:
		if senses.should_commit_to_moving():
			return state_machine.states.get("Moving")
		if senses.should_wake_agitated():
			return state_machine.states.get("Agitated")
	if enemy.behaviour_data.use_sight:
		if senses.check_awaken():
			return state_machine.states.get("Moving")
	return null
