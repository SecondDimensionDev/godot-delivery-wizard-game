class_name EnemySenses
extends Node3D
## Detection component: hearing (attention/jolt tracking) and sight (FOV +
## line-of-sight), gated by [member EnemyBehaviourData.use_hearing]/[member EnemyBehaviourData.use_sight].
##
## Ported from the archived Listener/StoneChoir scripts' hearing and vision
## logic. Detects only -- callers (States, via [member Enemy]) decide what to
## do with [method try_catch]'s result.

# CONSTANTS
const SOURCE_STALE_MS := 200 # source unheard longer than this re-baselines instead of "jolting"
const JOLT_DEADZONE := 1.5 # m/s of per-tick jolt ignored (gravity ramps, stair steps)
const CHANGE_WEIGHT := 0.8 # attention bought per m/s of jolt above the deadzone
const MAX_ATTENTION := 12.0 # cap so a racket doesn't buy hours of chase
const CALM_FRACTION := 0.6 # hysteresis: a state is left at threshold * this, not at threshold
const EYE_HEIGHT := 0.6 # a player's eye height, for line-of-sight checks
const SEEN_SAMPLE_FRACTIONS: Array[float] = [0.1, 0.5, 0.9] # feet, torso, head

# EXPORT VARIABLES
@export var parent: Enemy


# PUBLIC VARIABLES
var attention: float = 0.0 ## Accumulated hearing attention (0..MAX_ATTENTION).
var heard_position: Vector3 ## Last position that contributed hearing attention.
var heard_set: bool = false ## Whether heard_position has ever been set.


# PRIVATE VARIABLES
var _hearing_sources: Dictionary = {} # instance id -> {prev_pos, prev_vel, last_ms}


# PUBLIC FUNCTIONS
func update_hearing(delta: float) -> void: ## Accumulates attention from nearby player motion. Call once per physics tick.
	if delta <= 0.0 or not parent.behaviour_data or not parent.behaviour_data.use_hearing:
		return

	var now := Time.get_ticks_msec()
	var loudest := 0.0

	for player in get_tree().get_nodes_in_group("player"):
		var body := player as Node3D
		if body == null:
			continue

		var key := body.get_instance_id()
		var pos := body.global_position

		if not _hearing_sources.has(key) or now - (_hearing_sources[key]["last_ms"] as int) > SOURCE_STALE_MS:
			_hearing_sources[key] = {"prev_pos": pos, "prev_vel": Vector3.ZERO, "last_ms": now}
			continue

		var source: Dictionary = _hearing_sources[key]
		var vel := (pos - (source["prev_pos"] as Vector3)) / delta
		var prev_vel := source["prev_vel"] as Vector3
		source["prev_pos"] = pos
		source["prev_vel"] = vel
		source["last_ms"] = now

		var dist := _horizontal_distance(parent.global_position, pos)
		if dist > parent.behaviour_data.hearing_range:
			continue

		# Vertical jolts only: jump takeoffs/landings, not ordinary walking.
		var falloff := 1.0 - dist / parent.behaviour_data.hearing_range
		var vertical_jolt := absf(vel.y - prev_vel.y)
		if vertical_jolt > JOLT_DEADZONE:
			var contribution := (vertical_jolt - JOLT_DEADZONE) * CHANGE_WEIGHT * falloff
			attention = minf(attention + contribution, MAX_ATTENTION)
			if contribution > loudest:
				loudest = contribution
				heard_position = pos
				heard_set = true

	attention = maxf(attention - parent.behaviour_data.attention_decay * delta, 0.0)


func should_wake_agitated() -> bool: ## Attention high enough to leave Dormant.
	return attention >= parent.behaviour_data.agitate_threshold


func should_calm_to_dormant() -> bool: ## Attention low enough to return to Dormant.
	return attention < parent.behaviour_data.agitate_threshold * CALM_FRACTION


func should_commit_to_moving() -> bool: ## Attention high enough to commit to chasing.
	return attention >= parent.behaviour_data.chase_threshold and heard_set


func should_demote_to_agitated() -> bool: ## Attention low enough to fall back to Agitated.
	return attention < parent.behaviour_data.chase_threshold * CALM_FRACTION


func check_awaken() -> bool: ## Range + line-of-sight check from this enemy to the nearest player (dormant awaken).
	var sight_point := parent.global_position + Vector3(0.0, parent.behaviour_data.body_height * 0.5, 0.0)

	for player in get_tree().get_nodes_in_group("player"):
		var body := player as Node3D
		if body == null:
			continue
		var target := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		if sight_point.distance_to(target) <= parent.behaviour_data.detect_range and not _line_blocked(sight_point, target):
			return true
	return false


func is_seen_by_any_player() -> bool: ## Whether any player's aim cone + line-of-sight can currently see this enemy.
	for player in get_tree().get_nodes_in_group("player"):
		var body := player as Player
		if body == null or body.aim.length() < 0.01:
			continue

		var forward := body.aim.normalized()
		var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)

		for fraction in SEEN_SAMPLE_FRACTIONS:
			var sample := parent.global_position + Vector3(0.0, parent.behaviour_data.body_height * fraction, 0.0)
			var to_enemy := sample - eye
			var dist := to_enemy.length()
			if dist < 0.01:
				return true # standing inside it counts as seeing it

			var dir := to_enemy / dist
			var angle_deg := rad_to_deg(acos(clampf(forward.dot(dir), -1.0, 1.0)))
			if angle_deg > parent.behaviour_data.fov_half_angle_deg:
				continue
			if not _line_blocked(eye, sample):
				return true
	return false


func try_catch() -> Node3D: ## Returns the first player within catch_range, or null.
	for player in get_tree().get_nodes_in_group("player"):
		var body := player as Node3D
		if body != null and _horizontal_distance(parent.global_position, body.global_position) <= parent.behaviour_data.catch_range:
			return body
	return null


func reset() -> void: ## Clears accumulated hearing state (called on respawn).
	attention = 0.0
	heard_set = false
	_hearing_sources.clear()


# PRIVATE FUNCTIONS
func _line_blocked(from: Vector3, to: Vector3) -> bool: # World geometry can hide the target; the enemy's own body and all players never count as blockers.
	var exclude: Array[RID] = [parent.get_rid()]
	for player in get_tree().get_nodes_in_group("player"):
		var collider := player as CollisionObject3D
		if collider != null:
			exclude.append(collider.get_rid())

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
