class_name DeliveryEconomy
extends Node

## Cargo lifecycle, delivery/exit detection, and run-economy payouts for any level built
## on the delivery scaffold (DeliveryZone/ExitZone/DeliveryMarkers/CargoSpawn -- see
## lvl_warehouse.tscn). Composed via @export NodePaths (same dependency-injection style
## as MultiplayerManager) rather than a shared base class. Ported from fedex's GameLevel
## cargo/delivery surface, narrowed to just cargo + economy -- player spawn is
## MultiplayerManager's job here, not this component's.
##
## Wired into the level's Setup/Play flow with a single call: play_mode.gd calls
## begin_play() once entering Play, which reads the job the lobby's job computer picked
## (JobDefs.current_job_index) and spawns that job's cargo.

# SIGNALS
signal cargo_delivered(remaining_value: float, elapsed_seconds: float) ## Server-only.
signal players_exited ## Server-only: after a delivery, every player reached the exit.
signal player_respawned(peer_id: int) ## Server-only: a hazard/enemy sent this peer's player back to spawn.

# CONSTANTS
const CARGO_SCENES: Dictionary = { # cargo_kind (JobDefs) -> variant scene
	"box": preload("res://entities/cargo/cargo.tscn"),
	"barrel": preload("res://entities/cargo/cargo_barrel.tscn"),
}
const DELIVERY_MAX_SPEED := 0.5 # box must be at rest (and released) to count as delivered

# EXPORT VARIABLES
@export var cargo_holder: Node3D ## Parent for the spawned Cargo instance.
@export var delivery_zone: Area3D
@export var delivery_markers: Node3D ## Node3D whose children are named per JobDefs "zone" values.
@export var cargo_spawn: Marker3D
@export var exit_zone: Area3D
@export var exit_label: Label3D
@export var players_container: Node3D ## The level's Players node (see MultiplayerManager.player_container).
@export var exit_seconds := 20.0 ## How long the exit stays open after a delivery.

# PRIVATE VARIABLES
var _cargo_body: Cargo # server-side handle to the live cargo
var _cargo_spawn_value := 0.0 # the job's reward at spawn time (damage-free check baseline)
var _cargo_spawned_ms := 0 # when the current box appeared (for the time bonus)
var _delivery_armed := false # one cargo_delivered per box
var _exit_open := false # after a delivery: the exit is live (checked on the server)
var _exit_deadline_ms := 0 # local countdown display; every peer got the same seconds


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Every sibling hazard/enemy that sends players back to spawn reports it via a
	# server-side `player_caught(peer_id)` signal; relay them all up so the run economy
	# can charge the respawn fee, same auto-wiring GameLevel used to do.
	for node in get_parent().find_children("*", "", true, false):
		if node.has_signal("player_caught"):
			node.connect("player_caught", _on_player_caught)


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_check_delivery()
	if _exit_open:
		_check_exit()


func _process(_delta: float) -> void:
	# Countdown on the EXIT label, on every peer (cosmetic; _exit_deadline_ms is set
	# identically everywhere by _reveal_exit's RPC).
	if not _exit_open or exit_label == null:
		return
	var left := maxi(0, _exit_deadline_ms - Time.get_ticks_msec())
	exit_label.text = "EXIT  %d" % ceili(float(left) / 1000.0)


# PUBLIC FUNCTIONS
func begin_play() -> void:
	## Called once by play_mode.gd when this level's Play state begins.
	if not multiplayer.is_server():
		return
	apply_job(JobDefs.current_job_index)


func apply_job(job_index: int) -> void:
	## Server-only: positions the delivery zone per the job's "zone" marker and spawns
	## its cargo. No-op for levels with no job selected (job_index < 0).
	if job_index < 0 or job_index >= JobDefs.JOBS.size():
		return
	var job: Dictionary = JobDefs.JOBS[job_index]
	if delivery_zone != null and delivery_markers != null:
		var marker := delivery_markers.get_node_or_null(job["zone"]) as Marker3D
		if marker != null:
			delivery_zone.position = marker.position
	spawn_cargo(job["reward"], job["mass"], job["damage_per_speed"],
		job["com_offset"], job.get("cargo_kind", "box"))


func spawn_cargo(value: float, cargo_mass: float, damage_rate: float,
		com_offset: Vector3, cargo_kind: String = "box") -> void:
	## Server-only: spawn the job's cargo with per-difficulty parameters.
	if not multiplayer.is_server() or cargo_holder == null or cargo_spawn == null:
		return
	var scene: PackedScene = CARGO_SCENES.get(cargo_kind, CARGO_SCENES["box"])
	var c: Cargo = scene.instantiate()
	c.name = "Cargo"
	c.position = cargo_spawn.position
	c.value = value
	c.mass = cargo_mass
	c.damage_per_speed = damage_rate
	c.com_offset = com_offset
	c.net_position = c.position
	c.net_rotation = c.quaternion
	cargo_holder.add_child(c, true) # force_readable_name keeps a stable name on clients
	_cargo_body = c
	_cargo_spawn_value = value
	_cargo_spawned_ms = Time.get_ticks_msec()
	_delivery_armed = true


func despawn_cargo() -> void:
	## Server-only: free the spawned cargo (the spawner mirrors the despawn to clients).
	if _cargo_body != null and is_instance_valid(_cargo_body):
		_cargo_body.queue_free()
	_cargo_body = null
	_delivery_armed = false


# PRIVATE FUNCTIONS
func _on_player_caught(peer_id: int) -> void:
	# Enemies/hazards only emit player_caught on the server, so this stays server-only.
	player_respawned.emit(peer_id)
	var run := SessionManager.current_run as RunData
	if run:
		_broadcast_result.rpc(run.register_player_respawn())


func _check_delivery() -> void:
	# A box counts as delivered when it sits released and at rest inside the delivery
	# zone. The run economy decides what the delivery is worth and the exit opens (or
	# the run ends if the team went into debt).
	if delivery_zone == null:
		return # no cargo scaffold on this level
	if not _delivery_armed or _cargo_body == null or not is_instance_valid(_cargo_body):
		return
	if _cargo_body.is_grabbed():
		return
	if _cargo_body.linear_velocity.length() > DELIVERY_MAX_SPEED:
		return
	if not delivery_zone.overlaps_body(_cargo_body):
		return
	_delivery_armed = false
	var elapsed := float(Time.get_ticks_msec() - _cargo_spawned_ms) / 1000.0
	var remaining := _cargo_body.value
	var run := SessionManager.current_run as RunData
	if run:
		_broadcast_result.rpc(run.register_delivery(remaining, elapsed, _cargo_spawn_value))
	cargo_delivered.emit(remaining, elapsed)
	_reveal_exit.rpc(exit_seconds)


func _check_exit() -> void:
	# Server-only, while the exit is open: once EVERY player stands inside the exit
	# area, the whole team is "done with this job".
	if players_container == null or exit_zone == null:
		return
	for player in players_container.get_children():
		var body := player as PhysicsBody3D
		if body == null or not exit_zone.overlaps_body(body):
			return
	_exit_open = false
	players_exited.emit()


@rpc("authority", "call_local", "reliable")
func _reveal_exit(seconds: float) -> void:
	# Runs on EVERY peer after a delivery: reveal the exit area and start the local
	# countdown label. Only the server's _physics_process actually checks who's inside.
	if exit_zone == null:
		return
	exit_zone.visible = true
	_exit_deadline_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	_exit_open = true


@rpc("authority", "call_local", "reliable")
func _broadcast_result(msg: String) -> void:
	# PLACEHOLDER feedback until a HUD element exists: every peer logs the run-economy
	# message (payout, late fee, respawn fee...). Wire to a HUD label when one is built.
	if msg != "":
		print("[delivery] ", msg)
