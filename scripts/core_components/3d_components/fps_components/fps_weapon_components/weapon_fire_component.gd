class_name WeaponFireBehavior
extends Node3D
## Base class for all weapon firing mechanics.
##
## Extend this to create specific behaviors like hitscan or projectiles.
## Do not attach this script directly to a node; use an inherited script.

# PUBLIC FUNCTIONS
func fire(_weapon_data: FPSWeaponData) -> void: ## Virtual function to handle the actual firing logic.
	pass
