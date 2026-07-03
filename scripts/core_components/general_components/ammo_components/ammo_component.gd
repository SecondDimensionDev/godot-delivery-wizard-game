class_name AmmoComponent
extends Node
## Manages ammo reserves for an entity.
##
## This component stores ammo amounts keyed by a String (e.g., "9mm", "Shells").
## It provides methods to consume, add, and check ammo levels using 
## dependency injection.

# SIGNALS
signal ammo_changed(type: String, remaining: int) ## Emitted when any ammo count changes.
signal ammo_depleted(type: String) ## Emitted when a specific ammo type hits zero.

# EXPORT VARIABLES
@export var initial_ammo: Dictionary[String, int] = {
	"9mm": 60,
	"Shells": 12
} ## Set the starting ammo types and amounts in the Inspector.

@export var max_ammo_limits: Dictionary[String, int] = {
	"9mm": 200,
	"Shells": 50
} ## Defines the maximum capacity for each ammo type.

# PRIVATE VARIABLES
var _reserves: Dictionary[String, int] = {}

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Initialize our reserves from the starting data
	for type in initial_ammo:
		_reserves[type] = initial_ammo[type]

# PUBLIC FUNCTIONS
func get_ammo(type: String) -> int: ## Returns the current amount for a specific ammo type.
	return _reserves.get(type, 0)


func has_ammo(type: String) -> bool: ## Checks if the reserve for a type is greater than zero.
	return get_ammo(type) > 0


func add_ammo(type: String, amount: int) -> void: ## Adds ammo to reserves, respecting max limits.
	var current = get_ammo(type)
	var limit = max_ammo_limits.get(type, 999) # Default to 999 if no limit defined
	
	_reserves[type] = clampi(current + amount, 0, limit)
	ammo_changed.emit(type, _reserves[type])


func consume_ammo(type: String, amount_requested: int) -> int: ## Deducts ammo and returns the amount actually taken.
	var available = get_ammo(type)
	var amount_to_give = mini(available, amount_requested)
	
	_reserves[type] = available - amount_to_give
	
	ammo_changed.emit(type, _reserves[type])
	
	if _reserves[type] <= 0:
		ammo_depleted.emit(type)
		
	return amount_to_give


func check_max_capacity(type: String) -> bool: ## Returns true if the ammo type is at its limit.
	return get_ammo(type) >= max_ammo_limits.get(type, 999)
