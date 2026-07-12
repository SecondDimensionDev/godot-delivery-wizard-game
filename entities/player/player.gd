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

# PRIVATE VARIABLES


# BUILT-IN VIRTUAL METHODS
func _enter_tree() -> void: ## Set the multiplayer authority to the peer ID.
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	if player_state_machine:
		player_state_machine.state_changed.connect(_temp_state_change)


func _temp_state_change(old_state_name: String, new_state_name: String) ->void:
	print("Player State Changed from %s to %s" % [old_state_name, new_state_name])
