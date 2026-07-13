class_name Player
extends CharacterBody3D
## Root node for the player character.
##
## Acts as a data router, wiring up inputs to components like the
## MovementController. Manages the camera rig and mouse capture.

# EXPORT VARIABLES
@export_group("Component References")
@export var movement_controller: FPSMovementController ## Reference to the movement component.
@export var player_state_machine: StateMachine
@export var player_camera: FPSCameraViewfinder
@export var player_camera_controller: FPSCameraController
@export var player_view_model: PlayerViewModel
@export var lean_component: PlayerLeanComponent
@export var crouch_component: PlayerCrouchComponent
@export var recoil_component: FPSRecoilComponent
@export var camera_anchor: Marker3D
@export var player_model: Node3D
@export var anim_tree: AnimationTree
@export var animation_control: PlayerAnimationControl

# PUBLIC VARIABLES
@export var aim: Vector3 = Vector3(0.0, 0.0, -1.0) ## Synced world-space look direction (camera
	## forward). General-purpose: grab targeting, stabilize, and enemy "am I being watched"
	## checks all read this off whichever player they care about, so it lives on the root
	## rather than any one gameplay system's own component.

# PRIVATE VARIABLES
var _slip_factors: Array[float] = [] # active SlipperyZone factors (they call in/out)


# BUILT-IN VIRTUAL METHODS
func _enter_tree() -> void: ## Set the multiplayer authority to the peer ID.
	set_multiplayer_authority(name.to_int())
	add_to_group("players")


func _ready() -> void:
	if player_state_machine:
		player_state_machine.state_changed.connect(_temp_state_change)


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() and player_camera:
		aim = -player_camera.global_transform.basis.z


# PUBLIC FUNCTIONS
func teleport_to(target: Vector3) -> void: ## Snaps the player to target and kills momentum.
	global_position = target
	velocity = Vector3.ZERO


func enter_slip_zone(factor: float) -> void: ## Called by a SlipperyZone this body walked into.
	_slip_factors.append(factor)


func exit_slip_zone(factor: float) -> void: ## Called by a SlipperyZone this body left.
	_slip_factors.erase(factor)


func slip_factor() -> float: ## Lowest grip among zones we're currently inside; 1.0 = normal ground.
	var lowest := 1.0
	for factor in _slip_factors:
		lowest = minf(lowest, factor)
	return lowest


func _temp_state_change(old_state_name: String, new_state_name: String) ->void:
	print("Player State Changed from %s to %s" % [old_state_name, new_state_name])
