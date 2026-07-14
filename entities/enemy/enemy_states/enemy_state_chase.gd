## Enemy State - Moving/Chase
extends State
## Advances toward whatever EnemySenses is currently tracking: the last heard
## spot for a hearing-based enemy (Listener; it's blind, so it walks to the
## SPOT, not the mover), or the nearest player for a sight-based one (Stone
## Choir). Catches take priority every tick; demotes back to Agitated/Observed
## if the enemy loses the target.

# PUBLIC VARIABLES
var enemy: Enemy
var senses: EnemySenses
var nav: EnemyNavigationController
var movement: EnemyMovementController
var rotation: EnemyRotationController

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	senses = enemy.enemy_senses
	nav = enemy.enemy_naviagation_controller
	movement = enemy.enemy_movement_controller
	rotation = enemy.enemy_rotation_controller


func update(delta: float) -> State:
	if enemy.behaviour_data.use_hearing and senses.should_demote_to_agitated():
		movement.stop(delta)
		return state_machine.states.get("Agitated")

	if enemy.behaviour_data.use_sight and senses.is_seen_by_any_player():
		movement.stop(delta)
		return state_machine.states.get("Observed")

	var caught := senses.try_catch()
	if caught:
		movement.stop(delta)
		enemy.trigger_catch(caught)
		return state_machine.states.get("Catch")

	var target: Variant = _current_target()
	if target == null:
		movement.stop(delta)
		return null

	nav.set_target(target)
	var pos_before := enemy.global_position
	movement.move_toward_point(nav.get_next_step(), delta)
	rotation.face_direction(enemy.global_position - pos_before, delta)
	return null


# PRIVATE FUNCTIONS
func _current_target() -> Variant:
	if enemy.behaviour_data.use_hearing:
		return senses.heard_position if senses.heard_set else null
	if enemy.behaviour_data.use_sight:
		return _nearest_player_position()
	return null


func _nearest_player_position() -> Variant:
	var best: Node3D = null
	var best_dist := INF
	for player in enemy.get_tree().get_nodes_in_group("player"):
		var body := player as Node3D
		if body == null:
			continue
		var dist := enemy.global_position.distance_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best = body
	return best.global_position if best else null
