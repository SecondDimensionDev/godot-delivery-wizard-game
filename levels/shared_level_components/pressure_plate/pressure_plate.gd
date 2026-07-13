class_name PressurePlate
extends Area3D

## Step-on switch for a MovingPlatform. Every peer runs the visual press state locally
## (player positions are synced, so the overlap agrees everywhere); ONLY the server
## acts on it, calling toggle_target() on the wired platform. No RPCs: the press
## reaches the server through the normal player position sync, and the platform's own
## synchronizer carries the response back out. Standalone: place, point platform_path.

# SIGNALS
signal pressed ## Server-only: a player stepped on and the cooldown allowed a trigger.

# CONSTANTS
const LIT_ENERGY := 3.0 # plate emission while stood on
const IDLE_ENERGY := 0.8 # plate emission while idle

# EXPORT VARIABLES
@export var platform_path: NodePath ## The MovingPlatform this plate toggles.
@export var retrigger_cooldown := 1.5 ## Seconds before the plate can fire again.

# PRIVATE VARIABLES
@onready var _mesh: MeshInstance3D = $PlateMesh

var _platform: MovingPlatform
var _mat: StandardMaterial3D # per-instance copy so twin plates light independently
var _press_count := 0
var _ready_ms := 0 # server: earliest tick of the next allowed trigger


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_platform = get_node_or_null(platform_path) as MovingPlatform
	_mat = (_mesh.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_mesh.set_surface_override_material(0, _mat)
	_mat.emission_energy_multiplier = IDLE_ENERGY
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# PRIVATE FUNCTIONS
func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	_press_count += 1
	_mat.emission_energy_multiplier = LIT_ENERGY
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	if now < _ready_ms:
		return
	_ready_ms = now + int(retrigger_cooldown * 1000.0)
	if _platform != null:
		_platform.toggle_target()
	pressed.emit()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	_press_count = maxi(0, _press_count - 1)
	if _press_count == 0:
		_mat.emission_energy_multiplier = IDLE_ENERGY
