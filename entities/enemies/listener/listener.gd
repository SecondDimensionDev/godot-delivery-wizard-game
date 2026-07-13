class_name Listener
extends AnimatableBody3D

## Blind enemy that hunts DELIBERATE noise (design: plans/N1_listener_enemy.md, ported
## from fedex). It cannot see at all. Every physics tick the server "listens" to each
## noise source through its motion, but ordinary locomotion is SILENT: player ground
## velocity is bang-bang (0 <-> full speed instantly on WASD), so any horizontal measure
## turns plain walking/steering into noise and makes the mechanic pointless. Players are
## heard ONLY via vertical velocity steps -- jump takeoffs and landings. The cargo, a
## smooth physics body, is heard via true velocity jolts (drops, impacts, yanks); steadily
## dragging it habituates to silence. Enough attention makes it AGITATED (it turns toward
## the last sound); more locks it MOVING toward where it last heard something -- the spot,
## not the mover: it is blind. Only PLAYERS get caught (teleported back to the level
## spawn; the run economy pays the respawn fee via player_caught); cargo noise merely
## draws it to the spot. A catch lunges (ATTACKING), vanishes (GONE) and respawns dormant
## at its start point. Server-driven position + state, replicated the same never-snap way
## as StoneChoir; pathfinding via GridNav over the level GridMap, falling back to a
## straight-line advance with a wall-stop raycast when there is no GridMap.
##
## State transitions (Dormant/Agitated/Moving/Attacking/Gone) live in listener_states/ as
## State subclasses driven by the child StateMachine; this script holds the mechanics
## each state calls into: hearing, pathfinding, catch, replication, and the merged
## animation clips. Hearing itself is updated once per tick by this script (before the
## StateMachine child ticks), skipped entirely while Attacking/Gone -- attention does not
## accumulate mid-lunge or mid-vanish, matching the original design.
##
## Standalone: place directly in a level, no spawner needed.

# SIGNALS
signal player_caught(peer_id: int) ## Server-side: the Listener reached this peer's player.

# CONSTANTS
const SMOOTH := 18.0 # client smoothing rate toward net_position (matches Cargo.SMOOTH)
const IDLE_ANIM := &"zombie_idle1" # baked into listener_animated_skeletal.fbx
const AGITATED_ANIM := &"agitated-idle" ## "heard something, no lock yet" listening loop
const RUN_ANIM := &"zombie_run1" ## locomotion cycle, slowed to the drift via run_anim_scale
const ATTACK_ANIM := &"zombie_attack2_1" ## one-shot catch lunge
const ANIM_BLEND := 0.25 # seconds of cross-fade between state clips
const MOTION_CLIP_DIR := "res://assets/assets_meshes/enemy_meshes/listener"
const MOTION_CLIP_SCENES: Dictionary = { # clip name -> fbx carrying it (same AccuRig rig)
	&"agitated-idle": MOTION_CLIP_DIR + "/agitated_idle.fbx",
	&"zombie_run1": MOTION_CLIP_DIR + "/zombie_run1.fbx",
	&"zombie_run2": MOTION_CLIP_DIR + "/zombie_run2.fbx",
	&"zombie_attack2_1": MOTION_CLIP_DIR + "/zombie_attack2_1.fbx",
	&"zombie_dead2": MOTION_CLIP_DIR + "/zombie_dead.fbx",
}
const LOOPED_ANIMS: Array[StringName] = [ # cycles; the rest stay one-shot
	&"zombie_idle1", &"agitated-idle", &"zombie_run1", &"zombie_run2"]
const CHANGE_WEIGHT := 0.8 # attention bought per m/s of jolt: one close jump alerts it
	# (AGITATED); a jump + landing, repeated hopping, or a cargo slam accumulates past
	# chase_threshold before decay eats it
const JOLT_DEADZONE := 1.5 # m/s of per-tick jolt ignored (gravity ramps, stair steps)
const SOURCE_STALE_MS := 200 # source unheard longer than this re-baselines instead of "jolting"
const MAX_ATTENTION := 12.0 # cap so a racket doesn't buy hours of chase
const CALM_FRACTION := 0.6 # hysteresis: a state is left at threshold * this, not at threshold
const ATTACK_LINGER_MS := 900 # how long ATTACKING shows (zombie_attack2_1 is 0.82 s)
const REPATH_INTERVAL_MS := 300 # how often the path to the heard spot is recomputed
const WAYPOINT_RADIUS := 0.25 # horizontal distance at which a path waypoint counts reached
const HEARD_RADIUS := 0.6 # close enough to the heard spot to count as arrived
const TURN_RATE := 6.0 # facing slerp rate (travel direction, or the sound while AGITATED)
const RESPAWN_LIFT := Vector3(0.0, 1.0, 0.0) # caught players drop in above the spawn marker

# EXPORT VARIABLES
@export var move_speed := 1.6 ## Metres per second while MOVING -- a drift, not a sprint.
@export var run_anim_scale := 0.5 ## Run-clip playback speed while MOVING; retune with move_speed.
@export var hearing_range := 22.0 ## Beyond this, motion makes no impression at all.
@export var agitate_threshold := 2.0 ## Attention at which it wakes and turns toward the sound.
@export var chase_threshold := 6.0 ## Attention at which it commits and walks at the sound.
@export var attention_decay := 1.5 ## Attention lost per second of relative quiet.
@export var habituation_rate := 4.0 ## How fast the cargo's steady dragging noise fades to ignored (per second). Players don't use this -- their locomotion is silent by design.
@export var catch_range := 1.4 ## Horizontal distance to a player that counts as a catch.
@export var respawn_delay_ms := 4000 ## Time spent GONE before reappearing at its spawn point.
@export var mesh_forward_offset_deg := 180.0 ## Correction for the mesh's authored forward axis.
@export var path_clearance := 0.55 ## Hard minimum obstacle-free radius for a nav point.
@export var path_comfort := 1.15 ## Preferred obstacle-free radius; tighter points cost extra.
@export var grid_map_path: NodePath = ^"../GridMap" ## The level GridMap the nav grid is built from.
@export var player_spawn_path: NodePath = ^"../PlayerSpawn" ## Marker caught players are teleported back to.
@export var net_position: Vector3 ## Server-authoritative position, replicated to clients.
@export var net_rotation: Quaternion ## Server-authoritative facing, replicated to clients.
@export var net_state: String = "Dormant" ## Server-authoritative state name, replicated to clients.

# PRIVATE VARIABLES
@onready var _state_machine: StateMachine = $StateMachine
@onready var _mesh: Node3D = $ListenerMesh
@onready var _anim: AnimationPlayer = $ListenerMesh/AnimationPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _last_applied_state := "Dormant" # last state actually applied locally (avoid clip restarts)

# Server-only state.
var _spawn_position := Vector3.ZERO
var _spawn_rotation := Quaternion.IDENTITY
var _cargo: Cargo
var _nav := GridNav.new()
var _nav_done := false # try_build reached READY or FAILED (FAILED = fallback movement)
var _sources := {} # instance id -> {node, prev_pos, prev_vel, habit, last_ms}
var _attention := 0.0
var _heard_position := Vector3.ZERO # where it last heard something worth hearing
var _heard_set := false
var _path: PackedVector3Array # world-space waypoints toward _heard_position
var _path_index := 0
var _next_repath_ms := 0


# BUILT-IN VIRTUAL METHODS
func _enter_tree() -> void:
	add_to_group("listener") # enemies exclude each other from nav/hearing physics queries


func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = quaternion
	net_position = global_position
	net_rotation = quaternion
	_mesh.rotation.y = deg_to_rad(mesh_forward_offset_deg)
	_merge_motion_clips()
	_play_state_clip("Dormant")
	_state_machine.state_changed.connect(func(_old: String, new_name: String) -> void:
		net_state = new_name)
	if not multiplayer.is_server():
		_state_machine.set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if not _nav_done:
			var grid_map := get_node_or_null(grid_map_path) as GridMap
			match _nav.try_build(self, grid_map, path_clearance, path_comfort, _probe_exclusions()):
				GridNav.Build.READY:
					_nav_done = true
				GridNav.Build.FAILED:
					_nav_done = true
					push_warning("[listener] no usable GridMap at %s -- falling back to straight-line movement"
							% grid_map_path)
		# Attention does not accumulate mid-lunge or mid-vanish (matches fedex's original
		# early-returns before hearing/state updates while ATTACKING/GONE).
		if net_state != "Attacking" and net_state != "Gone":
			_update_hearing(delta)
		return # the StateMachine child's own _physics_process drives the rest
	# Client: smooth toward the replicated position/facing; never snap.
	var t := 1.0 - exp(-SMOOTH * delta)
	global_position = global_position.lerp(net_position, t)
	quaternion = quaternion.slerp(net_rotation, t)


func _process(_delta: float) -> void:
	_apply_visual_state() # every peer, including the host, mirrors the synced state


# PUBLIC FUNCTIONS (called by listener_states/*)
func sync_position() -> void:
	net_position = global_position


func should_wake_agitated() -> bool:
	return _attention >= agitate_threshold


func should_calm_to_dormant() -> bool:
	return _attention < agitate_threshold * CALM_FRACTION


func should_commit_to_moving() -> bool:
	return _attention >= chase_threshold and _heard_set


func should_demote_to_agitated() -> bool:
	return _attention < chase_threshold * CALM_FRACTION


func face_toward_heard(delta: float) -> void:
	_face_toward(_heard_position, delta)


func advance(delta: float) -> void:
	## Walk toward the heard SPOT (not the mover -- it is blind; the spot refreshes only
	## when something makes fresh noise). Arriving with nothing new to hear just leaves
	## it standing there, listening, until attention decays.
	if _horizontal_distance(global_position, _heard_position) <= HEARD_RADIUS:
		sync_position()
		return
	var pos_before := global_position
	var now := Time.get_ticks_msec()
	if _nav.is_ready():
		if now >= _next_repath_ms:
			_next_repath_ms = now + REPATH_INTERVAL_MS
			_path = _nav.path_points(global_position, _heard_position)
			_path_index = 0
		while _path_index < _path.size() \
				and _horizontal_distance(global_position, _path[_path_index]) <= WAYPOINT_RADIUS:
			_path_index += 1
		var goal := _heard_position if _path_index >= _path.size() else _path[_path_index]
		_step_toward(goal, delta)
	else:
		# Fallback (no GridMap): straight advance with a wall-stop raycast.
		var to_target := _heard_position - global_position
		to_target.y = 0.0
		if to_target.length() >= 0.01 and not _path_blocked(to_target.normalized(), move_speed * delta + 0.5):
			_step_toward(_heard_position, delta)
	_face_travel(global_position - pos_before, delta)
	sync_position()


func try_catch() -> bool:
	## PLAYERS only (enemies hunt players, not the box): the cargo's noise draws the
	## Listener to the spot, but arriving next to the box just leaves it listening there.
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null \
				and _horizontal_distance(global_position, body.global_position) <= catch_range:
			_trigger_player_catch(body)
			return true
	return false


func respawn() -> void:
	# sync_to_physics stays OFF for this body (scene default): besides sweeping teleports
	# into walls, it discards per-tick ROTATION writes outright -- the body could never
	# face its travel direction with it on (same finding as StoneChoir).
	global_position = _spawn_position
	quaternion = _spawn_rotation
	net_position = _spawn_position
	net_rotation = _spawn_rotation
	_attention = 0.0
	_heard_set = false
	_sources.clear()
	_path = PackedVector3Array()
	_path_index = 0


# PRIVATE FUNCTIONS
func _update_hearing(delta: float) -> void:
	# Blind listening: only DELIBERATE noise registers. See the class doc comment for
	# why players are heard exclusively via vertical velocity steps.
	if delta <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var loudest := 0.0
	for node in _hearing_candidates():
		var key := node.get_instance_id()
		var pos := node.global_position
		if not _sources.has(key) or now - (_sources[key]["last_ms"] as int) > SOURCE_STALE_MS:
			_sources[key] = {"node": node, "prev_pos": pos, "prev_vel": Vector3.ZERO,
					"habit": 0.0, "last_ms": now}
			continue
		var source: Dictionary = _sources[key]
		var vel := (pos - (source["prev_pos"] as Vector3)) / delta
		var prev_vel := source["prev_vel"] as Vector3
		source["prev_pos"] = pos
		source["prev_vel"] = vel
		source["last_ms"] = now
		var dist := _horizontal_distance(global_position, pos)
		if dist > hearing_range:
			source["habit"] = maxf((source["habit"] as float) - habituation_rate * delta, 0.0)
			continue
		var falloff := 1.0 - dist / hearing_range
		var contribution := 0.0
		if node is Cargo:
			var jolt := (vel - prev_vel).length()
			var steady := Vector2(vel.x, vel.z).length() * falloff
			source["habit"] = move_toward(source["habit"] as float, steady,
					habituation_rate * delta)
			contribution = maxf(steady - (source["habit"] as float), 0.0) * delta
			if jolt > JOLT_DEADZONE:
				contribution += (jolt - JOLT_DEADZONE) * CHANGE_WEIGHT * falloff
		else:
			# A player: jumps and landings only. Gravity ramps ~0.16 m/s per tick and
			# stair steps stay under the deadzone; takeoff/landing steps sail over it.
			var vertical_jolt := absf(vel.y - prev_vel.y)
			if vertical_jolt > JOLT_DEADZONE:
				contribution = (vertical_jolt - JOLT_DEADZONE) * CHANGE_WEIGHT * falloff
		if contribution > 0.001:
			_attention = minf(_attention + contribution, MAX_ATTENTION)
			if contribution > loudest:
				loudest = contribution
				_heard_position = pos
				_heard_set = true
	_attention = maxf(_attention - attention_decay * delta, 0.0)


func _hearing_candidates() -> Array[Node3D]:
	if _cargo == null or not is_instance_valid(_cargo):
		_cargo = get_tree().get_first_node_in_group("cargo") as Cargo
	var candidates: Array[Node3D] = []
	if _cargo != null and is_instance_valid(_cargo):
		candidates.append(_cargo)
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null:
			candidates.append(body)
	return candidates


func _step_toward(goal: Vector3, delta: float) -> void:
	var to_goal := goal - global_position
	to_goal.y = 0.0
	var dist := to_goal.length()
	if dist < 0.01:
		return
	global_position += (to_goal / dist) * minf(move_speed * delta, dist)


func _face_travel(displacement: Vector3, delta: float) -> void:
	displacement.y = 0.0
	if displacement.length() < 0.0005:
		return
	_face_toward(global_position + displacement, delta)


func _face_toward(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var desired := Quaternion(Basis.looking_at(dir.normalized(), Vector3.UP))
	quaternion = quaternion.slerp(desired, 1.0 - exp(-TURN_RATE * delta))
	net_rotation = quaternion


func _trigger_player_catch(player: Node3D) -> void:
	sync_position()
	var peer_id := player.get_multiplayer_authority()
	player_caught.emit(peer_id)
	var spawn := get_node_or_null(player_spawn_path) as Node3D
	var spawn_pos := player.global_position # no marker: scare without the teleport
	if spawn != null:
		spawn_pos = spawn.global_position + RESPAWN_LIFT
	else:
		push_warning("[listener] no PlayerSpawn at %s -- caught player not teleported"
				% player_spawn_path)
	_player_catch_effect.rpc(peer_id, spawn_pos)


func _probe_exclusions() -> Array[RID]:
	# Static level geometry is the only thing that should block nav points: never the
	# enemies themselves, the players, or the cargo (they move).
	var exclude: Array[RID] = []
	for group in ["listener", "stone_choir", "players", "cargo"]:
		for node in get_tree().get_nodes_in_group(group):
			var collider := node as CollisionObject3D
			if collider != null:
				exclude.append(collider.get_rid())
	return exclude


func _path_blocked(dir: Vector3, distance: float) -> bool:
	# Fallback mode only (no GridMap): short raycast ahead so it stops at walls instead
	# of walking through them. Excludes players and the cargo -- the things it chases.
	var exclude := _probe_exclusions()
	exclude.append(get_rid())
	var from := global_position + Vector3(0.0, 0.6, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * distance)
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# ANIMATION / VISUALS
func _merge_motion_clips() -> void:
	# The bought motions live one-clip-per-fbx on the same AccuRig skeleton, so each
	# clip is pulled straight into this AnimationPlayer's library -- no retargeting.
	var library := _anim.get_animation_library(&"")
	for clip_name: StringName in MOTION_CLIP_SCENES:
		if _anim.has_animation(clip_name):
			continue
		var packed := load(MOTION_CLIP_SCENES[clip_name]) as PackedScene
		if packed == null:
			push_warning("[listener] motion fbx missing: %s" % MOTION_CLIP_SCENES[clip_name])
			continue
		var donor := packed.instantiate()
		var donor_anim := donor.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if donor_anim == null or not donor_anim.has_animation(clip_name):
			push_warning("[listener] clip '%s' not inside %s"
					% [clip_name, MOTION_CLIP_SCENES[clip_name]])
			donor.free()
			continue
		var clip := donor_anim.get_animation(clip_name).duplicate() as Animation
		_strip_dead_tracks(clip)
		library.add_animation(clip_name, clip)
		donor.free()
	# Cycles ship non-looping; force the loop in code (same trick as StoneChoir's audio)
	# so it doesn't depend on the import settings.
	for anim_name in LOOPED_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _strip_dead_tracks(clip: Animation) -> void:
	# Donor fbxs carry a couple of tracks aimed at their own root/mesh nodes, which
	# don't exist under ListenerMesh; drop them so playback doesn't error-spam.
	for i in range(clip.get_track_count() - 1, -1, -1):
		var node_part := String(clip.track_get_path(i)).get_slice(":", 0)
		if _mesh.get_node_or_null(node_part) == null:
			clip.remove_track(i)


func _apply_visual_state() -> void:
	_mesh.visible = net_state != "Gone"
	_collision.disabled = net_state == "Gone"
	if net_state == _last_applied_state:
		return
	_last_applied_state = net_state
	_play_state_clip(net_state)


func _play_state_clip(state_name: String) -> void:
	match state_name:
		"Dormant":
			_play(IDLE_ANIM, 1.0)
		"Agitated":
			_play(AGITATED_ANIM, 1.0)
		"Moving":
			_play(RUN_ANIM, run_anim_scale)
		"Attacking":
			_play(ATTACK_ANIM, 1.0)
		"Gone":
			_anim.stop()


func _play(anim_name: StringName, speed: float) -> void:
	if not _anim.has_animation(anim_name):
		push_warning("[listener] clip '%s' missing -- staying on current pose" % anim_name)
		return
	_anim.play(anim_name, ANIM_BLEND, speed)


@rpc("authority", "call_local", "reliable")
func _player_catch_effect(peer_id: int, spawn_pos: Vector3) -> void:
	# Every peer gets the camera kick; the caught player's OWNING peer moves its own
	# body (players are owner-authoritative), the sync replicates the move.
	var active_camera := get_viewport().get_camera_3d()
	if active_camera:
		var shake := active_camera.get_node_or_null("CameraShakeComponent") as CameraShakeComponent
		if shake:
			shake.shake(0.5, 400)
	if multiplayer.get_unique_id() != peer_id:
		return
	for player in get_tree().get_nodes_in_group("players"):
		var body := player as Node3D
		if body != null and body.is_multiplayer_authority() and body.has_method("teleport_to"):
			body.teleport_to(spawn_pos)
