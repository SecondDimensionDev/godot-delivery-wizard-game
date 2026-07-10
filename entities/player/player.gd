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
@export var lean_component: PlayerLeanComponent
@export var crouch_component: PlayerCrouchComponent
@export var ammo_component: AmmoComponent
@export var weapon_manager: WeaponManagerComponent
@export var recoil_component: FPSRecoilComponent
@export var player_model: Node3D
@export var animation_tree: AnimationTree
@onready var animation_player_states = animation_tree.get("parameters/playback")

# PRIVATE VARIABLES
var _current_weapon: BaseWeapon = null

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if player_state_machine:
		player_state_machine.state_changed.connect(_temp_state_change)
	if is_instance_valid(weapon_manager):
		# Listen for whenever the active weapon changes
		weapon_manager.weapon_switched.connect(_on_weapon_switched)


func _temp_state_change(old_state_name: String, new_state_name: String) ->void:
	print("Player State Changed from %s to %s" % [old_state_name, new_state_name])


func _on_weapon_switched(weapon_data: FPSWeaponData, weapon_node: BaseWeapon) -> void:
	# 1. Clean up the old signal connection if it exists
	if is_instance_valid(_current_weapon) and _current_weapon.fired.is_connected(_on_weapon_fired):
		_current_weapon.fired.disconnect(_on_weapon_fired)
		
	_current_weapon = weapon_node
	
	# 2. Connect the new weapon's fire signal
	if is_instance_valid(_current_weapon):
		# We bind the weapon_data to the signal so our receiver function has the recoil stats
		_current_weapon.fired.connect(_on_weapon_fired.bind(weapon_data))


func _on_weapon_fired(weapon_data: FPSWeaponData) -> void:
	# 3. Route the weapon data stats into the recoil component
	if is_instance_valid(recoil_component) and weapon_data.apply_recoil:
		recoil_component.add_recoil(
			weapon_data.recoil_rotation,
			weapon_data.recoil_snap_amount,
			weapon_data.recoil_recovery_speed,
			weapon_data.recoil_randomness
		)
