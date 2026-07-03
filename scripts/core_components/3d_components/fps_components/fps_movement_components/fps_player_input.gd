class_name FPSPlayerInput extends Node
## Listens for player input and routes it to the WeaponManagerComponent.
##
## This decouples hardware input from the weapon system, allowing the
## weapon manager to be reused for NPCs or automated sequences.

# EXPORT VARIABLES
@export var weapon_manager: WeaponManagerComponent ## Reference to the manager to control.

# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(weapon_manager):
		return
		
	# Handle Firing
	if event.is_action_pressed("fire"):
		weapon_manager.pull_trigger()
	elif event.is_action_released("fire"):
		weapon_manager.release_trigger()
		
	# Handle Reloading
	if event.is_action_pressed("reload"):
		weapon_manager.reload()
		
	# Handle Weapon Swapping
	if event.is_action_pressed("next_weapon"):
		weapon_manager.cycle_next()
	elif event.is_action_pressed("prev_weapon"):
		weapon_manager.cycle_prev()
		
	if event.is_action_pressed("aim"):
		weapon_manager.aim_down()
	elif event.is_action_released("aim"):
		weapon_manager.stop_aiming()
