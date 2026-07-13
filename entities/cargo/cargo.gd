class_name Cargo
extends RigidBody3D

## The one strictly server-authoritative object. The server runs real physics and
## publishes its transform each tick; clients freeze it kinematic and interpolate
## toward the server's state (never snap). The server also applies push (proximity +
## player velocity) and carry (spring) forces from nearby players.
##
## Grab/carry intent comes from each player's [CarrySpell] (found via the
## "carry_spells" group) rather than bespoke properties on the player root -- see
## [member CarrySpell.is_casting]. Push intent is read straight off the player's own
## native [member CharacterBody3D.velocity]; no custom synced property is needed for it.

# CONSTANTS
const SMOOTH := 18.0 # client interpolation rate toward the server transform
const PUSH_GAIN := 250.0 # push strength; not mass-scaled, so several pushers matter
const EYE_HEIGHT := 0.6 # camera height above the player origin (matches Player's camera)
const HOLD_DISTANCE := 1.8 # fallback hold distance if it can't be measured at grab
const MIN_HOLD := 1.6 # closest the box can be reeled in while held
const MAX_HOLD := 3.5 # furthest the box can be pushed out while held
const HOLD_ADJUST := 1.0 # how strongly moving toward/away the box changes the hold distance
const STIFFNESS := 10000.0 # carry spring stiffness (a wand at full cap trails ~0.25 m)
const DAMPING := 400.0 # carry spring damping. Deliberately low next to the spring cap:
	# max carry speed = cap / total damping, so a fully-crewed heavy box moves at
	# ~2.7 m/s and every extra wand above the minimum makes the carry faster.
const CARRY_MUSCLE := 1.0 # per-grabber spring force cap, in multiples of the weight of
	# LIFT_PER_GRABBER mass units. Uncapped, the spring lets ONE player hoist any mass
	# (force grows with displacement); capped, heavy jobs genuinely need more wizards.
const HOLD_HEIGHT_BASE := -0.4 # a lone grabber's hold target tops out this far above
	# their eye (negative = chest height: solo is a low drag-carry, never a hoist)
const HOLD_HEIGHT_PER_EXTRA := 0.8 # each ADDITIONAL grabber raises that ceiling by this
	# many metres -- lifting the cargo high is a headcount problem, not an aim trick
const LIFT_PER_GRABBER := 250.0 # weight units one wand handles comfortably. Job weights
	# are round multiples: 250 = solo, 500 = two wands, 1000 = the full four-player crew
	# (under-crewed boxes drag along the ground, crewed ones hover)
const GRAB_RANGE := 3.0 # max eye-to-surface distance to start a grab. Starting one also
	# requires LOOKING at the box: the aim ray must hit it.
const HOLD_BREAK_RANGE := 10.0 # a held grab snaps once eye-to-grab-point exceeds this.
	# A held grab also snaps when world geometry blocks the eye-to-grab-point line
	# (no carrying through walls); players never block each other's line.
const START_VALUE := 100.0 # dollar value of a fresh box
const SAFE_IMPACT := 2.5 # impact speed (m/s) under which the box takes no damage
	# (linear_damp 2.0 caps free fall at ~4.9 m/s, so this must sit well below that)
const DAMAGE_COOLDOWN_MS := 300 # so one crash landing doesn't multi-count
const STABILIZE_RANGE := 5.0 # max eye-to-surface distance a stabilizer can act from
const STABILIZE_COOLDOWN_MS := 1500 # per-player wait between stabilize pulses
const STABILIZE_DAMP := 0.6 # fraction of linear/angular velocity removed per pulse
const STABILIZE_PULSE_MS := 300 # how long the cosmetic STABILIZED flash lasts
const CATASTROPHIC_IMPACT := 6.0 # m/s -- above this a catastrophic hit fires (damped
	# free-fall tops out ~4.9 m/s, so only a genuinely hurled box crosses it)
const CATASTROPHIC_LOSS_FRACTION := 0.25 # fraction of REMAINING value lost on top
const CATASTROPHE_LABEL_MS := 500 # how long the CRACK flash stays up
const CATASTROPHE_SHAKE_STRENGTH := 0.35 # local camera shake amplitude (metres)
const CATASTROPHE_SHAKE_MS := 300 # shake decay time

# EXPORT VARIABLES
@export var damage_per_speed := 8.0 ## Dollars lost per m/s of impact over SAFE_IMPACT. Set per job by the level on spawn (server-only; damage is assessed on the server).
@export var com_offset: Vector3 = Vector3.ZERO ## Local-space centre-of-mass offset (per job). The server applies it to the RigidBody; clients only place the ComTell marker.
@export var net_position: Vector3 ## Server-authoritative position, replicated to clients.
@export var net_rotation: Quaternion ## Server-authoritative rotation, replicated to clients.
@export var value := START_VALUE ## Remaining dollar value (server-authoritative, replicated). Can go negative -- deliveries then COST money.

# PRIVATE VARIABLES
@onready var _push_zone: Area3D = $PushZone
@onready var _half_extents: Vector3 = _read_half_extents()
@onready var _value_label: Label3D = $ValueLabel
@onready var _com_tell: MeshInstance3D = $ComTell
@onready var _stabilize_label: Label3D = $StabilizeLabel
@onready var _catastrophe_label: Label3D = $CatastropheLabel
@onready var _crack_audio: AudioStreamPlayer3D = $CrackAudio
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _start_value: float # spawn value (per-job), normalises the damage shader uniform
var _shader_material: ShaderMaterial # cached in _ready; drives the damage visual
var _grabbers: Dictionary = {} # player instance id -> {player, spell, distance, point} while carrying
var _stabilize_ready_ms: Dictionary = {} # peer id -> earliest ms of their next stabilize (server-only)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _next_damage_ms := 0
var _prev_velocity := Vector3.ZERO # velocity at the START of the tick; body_entered fires
	# after the solver has absorbed the hit, so this is the true pre-impact speed


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	add_to_group("cargo") # so other systems (enemies, hazards) can find the shared cargo
	_com_tell.position = com_offset # grey-box tell so the off-balance load is legible
	_start_value = maxf(value, 1.0) # avoid divide-by-zero if a job ever spawns at $0
	_shader_material = _mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if multiplayer.is_server():
		# Off-centre mass: applied before the first physics tick so the inertia tensor
		# is derived once. The carry spring already acts at the grab point offset from
		# the COM, so the swing/balance behaviour falls out for free.
		center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = com_offset
		# Server simulates normally, and is the only peer that assesses impact damage.
		contact_monitor = true
		max_contacts_reported = 8
		body_entered.connect(_on_body_entered)
		return
	# Client: become a kinematic stand-in driven toward the server's transform; it
	# never falls or reacts to forces locally.
	freeze_mode = FREEZE_MODE_KINEMATIC
	freeze = true
	global_position = net_position # seed so the first frame doesn't lerp from origin
	quaternion = net_rotation


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_prev_velocity = linear_velocity # pre-impact speed for this tick's collisions
	net_position = global_position
	net_rotation = quaternion
	_apply_player_forces(delta)


func _process(delta: float) -> void:
	_update_value_label()
	_update_damage_uniform()
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
	# Frame-rate-independent smoothing toward the latest server state. Never snaps.
	var t := 1.0 - exp(-SMOOTH * delta)
	global_position = global_position.lerp(net_position, t)
	quaternion = quaternion.slerp(net_rotation, t)


# PUBLIC FUNCTIONS
func is_grabbed() -> bool:
	## True while any player is carrying the box (server-side truth).
	return not _grabbers.is_empty()


func aim_hit_distance(eye: Vector3, dir: Vector3, max_dist: float) -> float:
	## Ray/shape test from `eye` along `dir` (world space): distance to this cargo's
	## surface, or -1.0 on miss/too far. Base impl is the box slab test; shape
	## variants (CargoBarrel) override.
	return _aim_hit_distance(eye, dir, max_dist)


@rpc("any_peer", "call_remote", "reliable")
func request_stabilize() -> void:
	## Server-only: a NON-grabbing player aiming at the box within STABILIZE_RANGE
	## damps its velocity (one pulse, per-player cooldown). Gives the player who
	## stays off the box a real job. Clients call this via rpc_id(1); the host
	## player calls it directly (sender id 0 = local = peer 1).
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1 # direct local call from the host's own player
	var body: Player = null
	for player in get_tree().get_nodes_in_group("players"):
		if (player as Node).name.to_int() == peer_id:
			body = player as Player
			break
	if body == null or _grabbers.has(body.get_instance_id()):
		return # unknown caller, or a grabber -- stabilizing is for helpers only
	if Time.get_ticks_msec() < int(_stabilize_ready_ms.get(peer_id, 0)):
		return # still on cooldown
	if body.aim.length() < 0.01:
		return
	var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	if aim_hit_distance(eye, body.aim.normalized(), STABILIZE_RANGE) < 0.0:
		return # not looking at the box, or too far away
	linear_velocity *= 1.0 - STABILIZE_DAMP
	angular_velocity *= 1.0 - STABILIZE_DAMP
	_stabilize_ready_ms[peer_id] = Time.get_ticks_msec() + STABILIZE_COOLDOWN_MS
	_stabilize_effect.rpc()


func hazard_reset(pos: Vector3, penalty: float) -> void:
	## Server-only (called by a HazardPit that swallowed the box): deduct the penalty
	## and snap the box back to a safe spot with dead velocities. Clients get a one-shot
	## snap RPC instead of lerping across the map. Grabs self-heal: after the snap every
	## grabber exceeds HOLD_BREAK_RANGE and _apply_player_forces erases them next tick.
	if not multiplayer.is_server():
		return
	value -= penalty
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	net_position = pos
	net_rotation = quaternion
	_snap_to.rpc(pos, quaternion)


func apply_enemy_catch(loss_fraction: float, knockback: Vector3) -> void:
	## Server-only (called by an enemy that caught the box): shave a fraction off the
	## CURRENT value and shove the box away. No teleport/snap -- this is a scare and a
	## cost, not a hard reset like hazard_reset.
	if not multiplayer.is_server():
		return
	var loss := value * loss_fraction
	value -= loss
	linear_velocity += knockback


@rpc("authority", "call_remote", "reliable")
func _snap_to(pos: Vector3, rot: Quaternion) -> void:
	# One-shot exception to the never-snap rule, ordered by the server for teleports
	# only; normal interpolation resumes next frame.
	global_position = pos
	quaternion = rot


# PRIVATE FUNCTIONS
func _read_half_extents() -> Vector3:
	# Box-shape half extents for the slab test; non-box variants (barrel) don't use
	# it and just get ZERO instead of a crash from the BoxShape3D cast.
	var shape: Shape3D = ($CollisionShape3D as CollisionShape3D).shape
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size * 0.5
	return Vector3.ZERO


func _clamp_grab_point(local: Vector3) -> Vector3:
	# Clamp a candidate grab point to this cargo's surface, in local space. Base
	# impl is the box; shape variants override.
	return local.clamp(-_half_extents, _half_extents)


@rpc("authority", "call_local", "reliable")
func _stabilize_effect() -> void:
	# Runs on every peer: flash the STABILIZED label so the pulse is visible even to
	# players who weren't looking at the stabilizer.
	_stabilize_label.visible = true
	_stabilize_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_stabilize_label, "modulate:a", 0.0,
		float(STABILIZE_PULSE_MS) / 1000.0)
	tween.tween_callback(func() -> void: _stabilize_label.visible = false)


func _update_damage_uniform() -> void:
	# Every peer: drive the crack/tint shader from the replicated value. Purely
	# cosmetic -- glance-legible "how banged up is this thing" from across the room.
	if _shader_material == null:
		return
	var damage := clampf(1.0 - value / _start_value, 0.0, 1.0)
	_shader_material.set_shader_parameter("damage", damage)


func _update_value_label() -> void:
	_value_label.text = "$%d" % roundi(value)
	_value_label.modulate = Color(1, 0.3, 0.3) if value < 0.0 else Color(1, 1, 1)


func _on_body_entered(body: Node) -> void:
	# Server-only (connected there). Hard impacts with the world damage the box; being
	# nudged by players does not -- they interact through push/carry impulses instead.
	if body.is_in_group("players"):
		return
	var now := Time.get_ticks_msec()
	if now < _next_damage_ms:
		return
	# The solver has already absorbed most of the hit by the time this signal fires,
	# so judge by the faster of current and start-of-tick (pre-impact) velocity.
	var speed := maxf(linear_velocity.length(), _prev_velocity.length())
	if speed <= SAFE_IMPACT:
		return
	_next_damage_ms = now + DAMAGE_COOLDOWN_MS
	# Catastrophic tier: a hurled box loses a chunk of its REMAINING value BEFORE the
	# linear wear, so one monstrous smash bites harder than steady bumps.
	var catastrophic := speed > CATASTROPHIC_IMPACT
	if catastrophic:
		value *= 1.0 - CATASTROPHIC_LOSS_FRACTION
	value -= (speed - SAFE_IMPACT) * damage_per_speed
	if catastrophic:
		_catastrophic_effect.rpc(speed)


@rpc("authority", "call_local", "reliable")
func _catastrophic_effect(speed: float) -> void:
	# Every peer: CRACK flash over the box, local camera shake, and the (stubbed)
	# audio sting. Purely cosmetic -- the value deduction already happened server-side.
	_catastrophe_label.text = "!!! CRACK  %.0f m/s !!!" % speed
	_catastrophe_label.visible = true
	_catastrophe_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(_catastrophe_label, "modulate:a", 0.0,
		float(CATASTROPHE_LABEL_MS) / 1000.0)
	tween.tween_callback(func() -> void: _catastrophe_label.visible = false)
	if _crack_audio.stream != null:
		_crack_audio.play() # sting drops in later by assigning the stream in-editor
	var active_camera := get_viewport().get_camera_3d()
	if active_camera:
		var shake := active_camera.get_node_or_null("CameraShakeComponent") as CameraShakeComponent
		if shake:
			shake.shake(CATASTROPHE_SHAKE_STRENGTH, CATASTROPHE_SHAKE_MS)


func _apply_player_forces(delta: float) -> void:
	# Server-side, uniform for host and clients. PushZone detects nearby players (a
	# plain RigidBody contact check fails: CharacterBody3D stops with a tiny gap). We
	# apply IMPULSES (force * delta): a resting body ignores continuous force.
	# Phase 1a: grabs. A player casting CarrySpell latches on only if they are CLOSE
	# (within GRAB_RANGE) and LOOKING at the box (their aim ray hits it). The grab
	# point is the exact spot on the surface they are looking at.
	for spell_node in get_tree().get_nodes_in_group("carry_spells"):
		var spell := spell_node as CarrySpell
		if spell == null or not spell.is_casting or spell.player == null:
			continue
		var body := spell.player
		var key := body.get_instance_id()
		if _grabbers.has(key):
			continue
		if body.aim.length() < 0.01:
			continue
		var aim := body.aim.normalized()
		var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		var hit_t := aim_hit_distance(eye, aim, GRAB_RANGE)
		if hit_t < 0.0:
			continue # not looking at the box, or too far
		var local: Vector3 = global_transform.affine_inverse() * (eye + aim * hit_t)
		_grabbers[key] = {
			"player": body,
			"spell": spell,
			"point": _clamp_grab_point(local),
			"distance": clampf(hit_t, MIN_HOLD, MAX_HOLD),
		}

	# Phase 1b: pushes still require PushZone overlap (shoulder-shoving is contact
	# range); active grabbers steer through the carry spring instead. Push intent is
	# just the player's own native CharacterBody3D velocity -- no bespoke sync needed.
	for body in _push_zone.get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		if not _grabbers.has(body.get_instance_id()):
			_push_from(body, (body as CharacterBody3D).velocity, delta)

	# Phase 2: carry for every active grabber -- even after they back away and the box
	# hangs outside the zone -- until they release the spell or despawn, walk out of
	# HOLD_BREAK_RANGE, or lose line of sight to their grab point (clean break: the
	# grabber is simply erased; they re-latch via Phase 1a once eligible again).
	for key in _grabbers.keys():
		var grabber: Dictionary = _grabbers[key]
		var body: Player = grabber["player"]
		var spell: CarrySpell = grabber["spell"]
		if not is_instance_valid(body) or not is_instance_valid(spell) or not spell.is_casting:
			_grabbers.erase(key)
			continue
		var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		var grab_world := global_position + global_transform.basis * (grabber["point"] as Vector3)
		if eye.distance_to(grab_world) > HOLD_BREAK_RANGE \
				or _grab_line_blocked(eye, grab_world):
			_grabbers.erase(key)
			continue
		_carry_toward(grabber, delta)

	# Hover assist: each grabber counteracts LIFT_PER_GRABBER mass units of weight,
	# capped at full weight. One player under-lifts a heavy box (it drags and dangles);
	# enough players together make it float at the held height.
	if not _grabbers.is_empty():
		var lift := minf(mass, LIFT_PER_GRABBER * float(_grabbers.size()))
		apply_central_impulse(Vector3.UP * lift * _gravity * delta)


func _push_from(body: Node3D, velocity: Vector3, delta: float) -> void:
	# Apply an IMPULSE (force * delta) toward the box: a resting body ignores
	# continuous force, but impulses wake and move it.
	var v := Vector3(velocity.x, 0.0, velocity.z)
	if v.length() < 0.05:
		return
	var to_cargo := global_position - body.global_position
	to_cargo.y = 0.0
	if to_cargo.length() < 0.001:
		return
	var dir := to_cargo.normalized()
	var approach := v.dot(dir) # how fast the player moves INTO the cargo
	if approach > 0.0:
		apply_central_impulse(dir * approach * PUSH_GAIN * delta)


func _grab_line_blocked(eye: Vector3, grab_world: Vector3) -> bool:
	# True when world geometry sits between the grabber's eye and their grab point.
	# The cargo itself and every player are excluded: the grab point is ON the cargo's
	# surface, and teammates crossing the tether must not break a carry.
	var exclude: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("players"):
		var collider := player as CollisionObject3D
		if collider != null:
			exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(eye, grab_world)
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _aim_hit_distance(eye: Vector3, dir: Vector3, max_dist: float) -> float:
	# Ray/box slab test in the cargo's local space: distance along `dir` from `eye`
	# to the box surface, or -1.0 if the ray misses or the surface is beyond
	# max_dist. Returns 0.0 when the eye is inside the box.
	var inv := global_transform.affine_inverse()
	var o := inv * eye
	var d := (inv.basis * dir).normalized()
	var t_min := 0.0
	var t_max := max_dist
	for axis in 3:
		var half := _half_extents[axis]
		if absf(d[axis]) < 0.00001:
			if absf(o[axis]) > half:
				return -1.0 # parallel to the slab and outside it
		else:
			var t1 := (-half - o[axis]) / d[axis]
			var t2 := (half - o[axis]) / d[axis]
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return -1.0
	return t_min


func _carry_toward(grabber: Dictionary, delta: float) -> void:
	# Hold the box along the player's LOOK direction at a dynamic distance: it tracks
	# where they look (yaw + pitch), moving toward it pushes it out and away reels it
	# in. It stays a real rigid body, so it collides and swings while held; forces from
	# multiple grabbers sum so the team can lift and shove together.
	var body: Player = grabber["player"]
	var aim := body.aim
	if aim.length() < 0.01:
		aim = Vector3(0.0, 0.0, -1.0)
	aim = aim.normalized()

	# Push/pull along the horizontal part of the look direction, driven by the
	# player's own native velocity (their movement input already steers it).
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	var approach := 0.0
	if flat_aim.length() > 0.001:
		approach = Vector3(body.velocity.x, 0.0, body.velocity.z).dot(flat_aim.normalized())
	var distance: float = grabber["distance"]
	distance = clampf(distance + approach * HOLD_ADJUST * delta, MIN_HOLD, MAX_HOLD)
	grabber["distance"] = distance

	var eye := body.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var target := eye + aim * distance
	# Height gate: the hold target can only aim so far up, and the ceiling rises with
	# the number of players on the cargo. Looking up steers the box, it doesn't crane it.
	target.y = minf(target.y, eye.y + HOLD_HEIGHT_BASE
		+ HOLD_HEIGHT_PER_EXTRA * float(_grabbers.size() - 1))
	# Apply the spring at the GRABBED POINT, not the centre of mass: this creates torque
	# so the held corner rises and the box dangles under gravity. Damp the velocity AT
	# that point (linear + angular) to keep it from spinning out.
	var point: Vector3 = grabber["point"]
	var r := global_transform.basis * point # grab-point offset from COM, world space
	var grab_world := global_position + r
	var point_vel := linear_velocity + angular_velocity.cross(r)
	# The spring part is capped at one grabber's "muscle" (the weight of LIFT_PER_GRABBER
	# mass units): a solo player cannot out-pull the weight of a heavy job no matter how
	# far the target is. Damping stays uncapped -- it only ever dissipates energy.
	var spring := ((target - grab_world) * STIFFNESS) \
		.limit_length(LIFT_PER_GRABBER * _gravity * CARRY_MUSCLE)
	var force := spring - point_vel * DAMPING
	apply_impulse(force * delta, r)
