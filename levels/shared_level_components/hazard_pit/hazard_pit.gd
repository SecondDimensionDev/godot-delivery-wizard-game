class_name HazardPit
extends Area3D

## Kill-volume for hazard pits: falling PLAYERS are teleported back to the checkpoint by
## their OWNING peer (players are owner-authoritative -- same split as WindZone/
## SlipperyZone); the falling CARGO loses a chunk of value and is snapped back by the
## SERVER (the one server-authoritative body). The run continues either way. The pit's
## visuals stay plain level geometry -- this component is only the rule. Standalone:
## place, size the CollisionShape3D, point respawn_path at a Marker3D.

# SIGNALS
signal body_dunked(body: Node3D) ## Something fell in (fires on the peer that acted on it).
signal player_caught(peer_id: int) ## Server-only: a player fell in. Same contract as enemy catch signals, so DeliveryEconomy's respawn-fee relay picks pits up too.

# CONSTANTS
const RESPAWN_LIFT := Vector3(0.0, 1.0, 0.0) # drop-in height above the marker
const RETRIGGER_MS := 500 # per-body debounce so one dunk can't double-fire

# EXPORT VARIABLES
@export var respawn_path: NodePath ## Marker3D players return to.
@export var cargo_respawn_path: NodePath ## Optional cargo return Marker3D (falls back to respawn_path).
@export var cargo_value_penalty := 20.0 ## Dollars deducted when the cargo takes a dip.

# PRIVATE VARIABLES
var _respawn: Node3D
var _cargo_respawn: Node3D
var _next_ok_ms: Dictionary = {} # body instance id -> earliest ms of its next dunk


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_respawn = get_node_or_null(respawn_path) as Node3D
	_cargo_respawn = get_node_or_null(cargo_respawn_path) as Node3D
	if _cargo_respawn == null:
		_cargo_respawn = _respawn
	body_entered.connect(_on_body_entered)


# PRIVATE FUNCTIONS
func _on_body_entered(body: Node3D) -> void:
	if _respawn == null:
		return
	var now := Time.get_ticks_msec()
	var key := body.get_instance_id()
	if now < int(_next_ok_ms.get(key, 0)):
		return
	if body.has_method("teleport_to"):
		# A player. body_entered fires on EVERY peer (all capsules exist everywhere):
		# only the OWNING peer moves its own body (the sync replicates the move), and
		# only the SERVER reports the dunk up for the respawn fee.
		_next_ok_ms[key] = now + RETRIGGER_MS
		if body.is_multiplayer_authority():
			body.teleport_to(_respawn.global_position + RESPAWN_LIFT)
			body_dunked.emit(body)
		if multiplayer.is_server():
			player_caught.emit(body.get_multiplayer_authority())
	elif body is Cargo and multiplayer.is_server():
		_next_ok_ms[key] = now + RETRIGGER_MS
		(body as Cargo).hazard_reset(
			_cargo_respawn.global_position + RESPAWN_LIFT, cargo_value_penalty)
		body_dunked.emit(body)
