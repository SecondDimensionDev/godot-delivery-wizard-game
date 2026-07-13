class_name StoneChoir
extends AnimatableBody3D

## "Don't look at it" statue enemy. Sits dormant and silent until it first spots a
## player (plain range + line-of-sight, no facing required -- it's sensing, not
## looking). Once awake, while no player can see any part of it, it advances toward the
## PLAYER who is closest by walking distance -- it hunts players only, never the cargo
## -- along a grid path derived from the level's GridMap (never through walls, always
## the shortest valid route, facing the way it travels). The instant any player sees
## any part of it (FOV + line-of-sight, no distance cap), it freezes. Catching a player
## teleports them back to the level spawn (the run economy pays the respawn fee via
## player_caught). The statue then vanishes, resets to dormant, and reappears at its
## spawn point after a short delay. Server-driven position + state, replicated the same
## never-snap way as MovingPlatform/Cargo; FOV/line-of-sight detection reuses Player's
## already-synced `aim` the same way Cargo's own grab check does.
##
## State transitions (Dormant/Moving/Observed/Gone) live in stone_choir_states/ as
## State subclasses driven by the child StateMachine -- this script holds only the
## mechanics each state calls into: senses, pathfinding (via GridNav), catch, and
## replication. The StateMachine only ticks on the server; clients just interpolate
## and mirror the replicated state for cosmetics (see _ready/_physics_process).
##
## Standalone: place directly in a level, no spawner needed. Pathfinding reads the
## GridMap at `grid_map_path` (default sibling "GridMap"); without one it falls back to
## the old straight-line advance with a wall-stop raycast.

# SIGNALS
signal player_caught(peer_id: int) ## Server-side: the statue reached this peer's player.

# CONSTANTS
const SMOOTH := 18.0 # client smoothing rate toward net_position (matches Cargo.SMOOTH)
const EYE_HEIGHT := 0.6 # matches Cargo.EYE_HEIGHT / Player's camera convention
const SIGHT_HEIGHT := 1.3 # vertical offset to the statue's visual centre; MUST match the
	# mesh/CollisionShape3D/audio-player Y offset in stone_choir.tscn so the dormant
	# awaken check (and the SFX) sense/emit from where the statue actually is, not its
	# ground-level root transform
const CAPSULE_HEIGHT := 2.6 # local height of the CollisionShape3D capsule in stone_choir.tscn
const SEEN_SAMPLE_FRACTIONS: Array[float] = [0.1, 0.5, 0.9] # heights up the body tested
	# for "can any player see any part of it" -- feet, torso, head
const REPATH_INTERVAL_MS := 250 # how often the target choice + path are recomputed
const WAYPOINT_RADIUS := 0.2 # horizontal distance at which a path waypoint counts reached
const TURN_RATE := 8.0 # facing slerp rate toward the travel direction (grid corners wheel, not snap)
const RESPAWN_LIFT := Vector3(0.0, 1.0, 0.0) # caught players drop in above the spawn marker

# EXPORT VARIABLES
@export var move_speed := 1.8 ## Metres per second while advancing (slower than the player).
@export var fov_half_angle_deg := 50.0 ## Cone half-angle a player must aim within to "see" it.
@export var detect_range := 18.0 ## Max distance for the dormant awaken check (freezing has no range cap).
@export var catch_range := 1.5 ## Distance to a player that counts as a catch.
@export var respawn_delay_ms := 3000 ## Time spent GONE before reappearing at its spawn point.
@export var mesh_forward_offset_deg := 90.0 ## Correction for the mesh's authored forward axis; rotates only the mesh child, so the collision body's facing (and net_rotation) stay tied to the true direction of travel.
@export var path_clearance := 0.55 ## Hard minimum obstacle-free radius for a nav point; anything tighter is impassable.
@export var path_comfort := 1.15 ## Preferred obstacle-free radius; tighter points cost extra so open routes win when they exist.
@export var grid_map_path: NodePath = ^"../GridMap" ## The level GridMap the nav grid is built from.
@export var player_spawn_path: NodePath = ^"../PlayerSpawn" ## Marker caught players are teleported back to.
@export var net_position: Vector3 ## Server-authoritative position, replicated to clients.
@export var net_rotation: Quaternion ## Server-authoritative facing, replicated to clients.
@export var net_state: String = "Dormant" ## Server-authoritative state name, replicated to clients.

# PRIVATE VARIABLES
@onready var _state_machine: StateMachine = $StateMachine
@onready var _mesh: Node3D = $StoneChoirMesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _whisper_audio: AudioStreamPlayer3D = $WhisperAudio
@onready var _chant_audio: AudioStreamPlayer3D = $ChantAudio

var _spawn_position := Vector3.ZERO
var _spawn_rotation := Quaternion.IDENTITY
var _cargo: Cargo # never chased -- kept only to exclude the box from movement raycasts
var _last_applied_state := "Dormant" # last state actually applied locally (avoid audio restarts)

# Server-only pathfinding state.
var _nav := GridNav.new()
var _nav_ready := false # the nav grid build finished (successfully or not)
var _target: Node3D # current chase target (a player)
var _path: PackedVector3Array # world-space waypoints toward _target
var _path_index := 0
var _next_repath_ms := 0
var _warned_no_path := false # log "nowhere to go" once, not every tick


# BUILT-IN VIRTUAL METHODS
func _enter_tree() -> void:
	add_to_group("stone_choir") # statues exclude each other from nav/vision physics queries


func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = quaternion
	net_position = global_position
	net_rotation = quaternion
	_mesh.rotation.y = deg_to_rad(mesh_forward_offset_deg)
	_force_loop(_whisper_audio.stream)
	_force_loop(_chant_audio.stream)
	_state_machine.state_changed.connect(func(_old: String, new_name: String) -> void:
		net_state = new_name)
	if not multiplayer.is_server():
		# State transitions are a server-only decision; clients only interpolate
		# position/facing and mirror the replicated net_state for cosmetics.
		_state_machine.set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if not _nav_ready:
			_nav_ready = _try_build_nav_grid()
		if _cargo == null or not is_instance_valid(_cargo):
			_cargo = get_tree().get_first_node_in_group("cargo") as Cargo
		return # the StateMachine child's own _physics_process drives the rest
	# Client: smooth toward the replicated position/facing; never snap.
	var t := 1.0 - exp(-SMOOTH * _delta)
	global_position = global_position.lerp(net_position, t)
	quaternion = quaternion.slerp(net_rotation, t)


func _process(_delta: float) -> void:
	_apply_visual_state() # every peer, including the host, mirrors the synced state


# PUBLIC FUNCTIONS (called by stone_choir_states/*)
func sync_position() -> void:
	net_position = global_position


func check_awaken() -> bool:
	## One-time trigger query: plain range + line-of-sight to a PLAYER from the statue's
	## own position, no facing required (it's dormant, sensing all around).
	var sight_point := global_position + Vector3(0.0, SIGHT_HEIGHT, 0.0)
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body == null:
			continue
		var target := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		if sight_point.distance_to(target) <= detect_range and not _line_blocked(sight_point, target):
			return true
	return false


func is_seen_by_any_player() -> bool:
	## "Any part visible, any distance": sample points up the statue's (scaled) body;
	## a player seeing ANY of them -- inside their aim cone with clear line of sight,
	## no range cap -- freezes it.
	var body_height := CAPSULE_HEIGHT * global_basis.get_scale().y
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Player
		if body == null or body.aim.length() < 0.01:
			continue
		var forward := body.aim.normalized()
		var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		for fraction in SEEN_SAMPLE_FRACTIONS:
			var sample := global_position + Vector3(0.0, body_height * fraction, 0.0)
			var to_statue := sample - eye
			var dist := to_statue.length()
			if dist < 0.01:
				return true # standing inside it counts as seeing it
			var dir := to_statue / dist
			var angle_deg := rad_to_deg(acos(clampf(forward.dot(dir), -1.0, 1.0)))
			if angle_deg > fov_half_angle_deg:
				continue
			if not _line_blocked(eye, sample):
				return true
	return false


func try_catch() -> bool:
	## Catch any PLAYER in reach, not just the current target (statues hunt players,
	## never the cargo -- the box is just an obstacle to shove past).
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null and _horizontal_distance_to(body.global_position) <= catch_range:
			_trigger_player_catch(body)
			return true
	return false


func advance(delta: float) -> void:
	## Move one tick toward the chase target (grid path if available, else the
	## straight-line fallback), then face the way it actually moved.
	var pos_before := global_position
	if _nav.is_ready():
		_grid_advance(delta)
	else:
		_fallback_advance(delta)
	_face_travel(global_position - pos_before, delta)
	sync_position()


func respawn() -> void:
	## GONE -> DORMANT reset: back to the spawn pose with a clean slate.
	global_position = _spawn_position
	quaternion = _spawn_rotation
	net_position = _spawn_position
	net_rotation = _spawn_rotation
	_target = null
	_path = PackedVector3Array()


func freeze_at_current_position() -> void:
	sync_position() # frozen (observed/gone): don't advance, just keep replication fresh


# PRIVATE FUNCTIONS
func _grid_advance(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _next_repath_ms or _target == null or not is_instance_valid(_target):
		_repath(now)
	if _target == null:
		return # nowhere reachable: stand rather than beeline through geometry
	# Follow the waypoint list; past its end, walk straight at the target itself for
	# the final approach (it's in/next to the target's own nav cell by then).
	while _path_index < _path.size() \
			and _horizontal_distance_to(_path[_path_index]) <= WAYPOINT_RADIUS:
		_path_index += 1
	var goal := _target.global_position if _path_index >= _path.size() else _path[_path_index]
	_step_toward(goal, delta)


func _fallback_advance(delta: float) -> void:
	# No GridMap found: the old straight-line advance with a wall-stop raycast, toward
	# the closest candidate as the crow flies. Keeps the component usable in test scenes.
	var best: Node3D = null
	var best_dist := INF
	for candidate in _chase_candidates():
		var dist := _horizontal_distance_to(candidate.global_position)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	if best == null:
		return
	var to_target := best.global_position - global_position
	to_target.y = 0.0
	if to_target.length() < 0.01:
		return
	var dir := to_target.normalized()
	if _path_blocked(dir, move_speed * delta + 0.5):
		return
	_step_toward(best.global_position, delta)


func _step_toward(goal: Vector3, delta: float) -> void:
	# Movement only; facing is derived afterwards from the ACTUAL displacement this tick
	# (_face_travel), so the statue can only ever face the way it truly moved.
	var to_goal := goal - global_position
	to_goal.y = 0.0
	var dist := to_goal.length()
	if dist < 0.01:
		return
	global_position += (to_goal / dist) * minf(move_speed * delta, dist)


func _face_travel(displacement: Vector3, delta: float) -> void:
	# Face the way it's traveling -- by construction: turn toward the position delta the
	# tick actually produced, wheeling around grid corners instead of snapping. No
	# movement, no turn (frozen/blocked statues keep their last travel facing).
	displacement.y = 0.0
	if displacement.length() < 0.0005: # ~1/60 of a metre-per-second: genuinely stationary
		return
	var desired := Quaternion(Basis.looking_at(displacement.normalized(), Vector3.UP))
	quaternion = quaternion.slerp(desired, 1.0 - exp(-TURN_RATE * delta))
	net_rotation = quaternion


func _repath(now: int) -> void:
	# Recompute the closest candidate BY WALKING DISTANCE and the path to it.
	_next_repath_ms = now + REPATH_INTERVAL_MS
	_target = null
	_path = PackedVector3Array()
	_path_index = 0
	var best_len := INF
	for candidate in _chase_candidates():
		var points := _nav.path_points(global_position, candidate.global_position)
		# An empty result means "off-grid or unreachable" almost always; the only false
		# positive is a candidate already in the statue's own nav cell, which try_catch()
		# handles independently via catch_range, so skipping here is the safe default.
		if points.is_empty():
			continue
		var length := _path_length(points, candidate.global_position)
		if length < best_len:
			best_len = length
			_target = candidate
			_path = points
	if _target == null:
		_warn_no_path("no candidate reachable from %s" % global_position)
	else:
		_warned_no_path = false


func _chase_candidates() -> Array[Node3D]:
	# Players only: the cargo is never chased (it still matters to movement -- see the
	# raycast exclusions -- but as an obstacle, not prey).
	var candidates: Array[Node3D] = []
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null:
			candidates.append(body)
	return candidates


func _path_length(points: PackedVector3Array, target_pos: Vector3) -> float:
	# Horizontal length statue -> waypoints -> the target's actual position.
	var length := 0.0
	var prev := global_position
	for point in points:
		length += _horizontal_distance(prev, point)
		prev = point
	return length + _horizontal_distance(prev, target_pos)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _horizontal_distance_to(point: Vector3) -> float:
	return _horizontal_distance(global_position, point)


func _warn_no_path(detail: String) -> void:
	if _warned_no_path:
		return
	_warned_no_path = true
	push_warning("[stone_choir] no valid path: %s" % detail)


func _try_build_nav_grid() -> bool:
	var grid_map := get_node_or_null(grid_map_path) as GridMap
	if grid_map == null:
		push_warning("[stone_choir] no GridMap at %s -- falling back to straight-line movement"
				% grid_map_path)
		return true
	var result := _nav.try_build(self, grid_map, path_clearance, path_comfort, _nav_probe_exclusions())
	match result:
		GridNav.Build.READY:
			return true
		GridNav.Build.FAILED:
			push_warning("[stone_choir] nav grid build failed -- falling back to straight-line movement")
			return true
		_: # RETRY
			return false


func _nav_probe_exclusions() -> Array[RID]:
	# Static level geometry is the only thing that should block nav points: never the
	# statues themselves, the players, or the cargo (they move).
	var exclude: Array[RID] = []
	for group in ["stone_choir", "players", "cargo"]:
		for node in get_tree().get_nodes_in_group(group):
			var collider := node as CollisionObject3D
			if collider != null:
				exclude.append(collider.get_rid())
	return exclude


# SENSES
func _line_blocked(eye: Vector3, target: Vector3) -> bool:
	# Mirrors Cargo._grab_line_blocked's exclusion convention: world geometry can hide
	# the statue, but the statue's own body and every player never count as blockers.
	var exclude: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("players"):
		var collider := player as CollisionObject3D
		if collider != null:
			exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _path_blocked(dir: Vector3, distance: float) -> bool:
	# Fallback mode only (no GridMap): short raycast ahead so the statue stops at walls
	# instead of walking through them. Excludes players and the cargo itself so it isn't
	# halted by the very thing it's chasing.
	var exclude: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("players"):
		var collider := player as CollisionObject3D
		if collider != null:
			exclude.append(collider.get_rid())
	if _cargo != null and is_instance_valid(_cargo):
		exclude.append(_cargo.get_rid())
	var from := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * distance)
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# CATCHES
func _trigger_player_catch(player: Node3D) -> void:
	net_position = global_position
	var peer_id := player.get_multiplayer_authority()
	player_caught.emit(peer_id)
	var spawn := get_node_or_null(player_spawn_path) as Node3D
	var spawn_pos := player.global_position # no marker: scare without the teleport
	if spawn != null:
		spawn_pos = spawn.global_position + RESPAWN_LIFT
	else:
		push_warning("[stone_choir] no PlayerSpawn at %s -- caught player not teleported"
				% player_spawn_path)
	_player_catch_effect.rpc(peer_id, spawn_pos)


func _apply_visual_state() -> void:
	_mesh.visible = net_state != "Gone"
	_collision.disabled = net_state == "Gone"
	if net_state == _last_applied_state:
		return
	_last_applied_state = net_state
	match net_state:
		"Dormant":
			_whisper_audio.stop()
			_chant_audio.stop()
		"Moving":
			_whisper_audio.stop()
			if not _chant_audio.playing:
				_chant_audio.play()
		"Observed":
			_chant_audio.stop()
			if not _whisper_audio.playing:
				_whisper_audio.play()
		"Gone":
			_whisper_audio.stop()
			_chant_audio.stop()


func _force_loop(stream: AudioStream) -> void:
	# Force looping in code so it doesn't depend on the .mp3's import setting.
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true


@rpc("authority", "call_local", "reliable")
func _player_catch_effect(peer_id: int, spawn_pos: Vector3) -> void:
	# PLACEHOLDER jump-scare for a player catch -- a camera kick on every peer for now;
	# the real caught-by-the-choir moment is still to be designed.
	var active_camera := get_viewport().get_camera_3d()
	if active_camera:
		var shake := active_camera.get_node_or_null("CameraShakeComponent") as CameraShakeComponent
		if shake:
			shake.shake(0.5, 400)
	if multiplayer.get_unique_id() != peer_id:
		return
	# The caught player's OWNING peer moves its own body (players are
	# owner-authoritative -- same split as HazardPit); the sync replicates the move.
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null and body.is_multiplayer_authority() and body.has_method("teleport_to"):
			body.teleport_to(spawn_pos)
