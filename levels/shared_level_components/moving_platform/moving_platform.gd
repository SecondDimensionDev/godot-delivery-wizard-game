class_name MovingPlatform
extends AnimatableBody3D

## Server-driven two-stop ferry platform. The server advances a 0..1 progress along a
## fixed travel line and a MultiplayerSynchronizer replicates it; clients smooth their
## local copy toward the synced value (same never-snap pattern as Cargo). Players ride
## their LOCAL copy via move_and_slide floor contact (sync_to_physics gives it a real
## velocity); the cargo rests on the SERVER's copy and its own net interpolation
## carries clients. Standalone: place it, aim `travel_offset`, wire a PressurePlate.

# SIGNALS
signal arrived(end_index: int) ## Server-only: the platform reached stop 0 (start) or 1 (far end).

# CONSTANTS
const SMOOTH := 18.0 # client smoothing rate toward the synced progress (matches Cargo.SMOOTH)

# EXPORT VARIABLES
@export var travel_offset := Vector3(0.0, 0.0, 6.8) ## World-space offset from the authored pose to the far stop.
@export var speed := 2.5 ## Metres per second along the travel line.
@export var depart_delay := 1.0 ## Seconds between a toggle and moving off (hop-on window).
@export var net_progress := 0.0 ## Replicated 0..1 along the travel line (server-authoritative).
@export var net_target := 0 ## Replicated destination stop (0 = start, 1 = far end).

# PRIVATE VARIABLES
var _origin := Vector3.ZERO # authored global start pose, captured before any travel
var _travel_len := 1.0
var _progress := 0.0 # client-local smoothed copy of net_progress
var _depart_ms := 0 # server: earliest tick the platform may move after a toggle


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_origin = global_position
	_travel_len = maxf(travel_offset.length(), 0.001)
	_progress = net_progress


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		# Server (or offline test): integrate the real progress.
		if Time.get_ticks_msec() >= _depart_ms:
			var before := net_progress
			net_progress = move_toward(net_progress, float(net_target),
				speed / _travel_len * delta)
			if net_progress != before and net_progress == float(net_target):
				arrived.emit(net_target)
		global_position = _origin + travel_offset * net_progress
		return
	# Client: smooth toward the replicated progress; never snap.
	_progress = lerpf(_progress, net_progress, 1.0 - exp(-SMOOTH * delta))
	global_position = _origin + travel_offset * _progress


# PUBLIC FUNCTIONS
func toggle_target() -> void:
	## Server-only (call down from a PressurePlate): send the platform to the other
	## stop after `depart_delay` seconds.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	net_target = 1 - net_target
	_depart_ms = Time.get_ticks_msec() + int(depart_delay * 1000.0)
