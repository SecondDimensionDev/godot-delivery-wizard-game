class_name DamageModifier
extends Resource
## A modular resource used to modify outgoing damage from a [DamageDealer].
##
## Extend this script to create custom effects like critical hits, elemental
## damage boosts, or temporary damage buffs.[br]
## Add these to the modifiers array of a [DamageDealer].

# EXPORT VARIABLES
@export var priority: int = 0 ## Higher priority modifiers are calculated first

# PUBLIC FUNCTIONS
func modify_damage(amount: int, _damage_type: String) -> int: ## Virtual function to modify outgoing damage
	return amount
