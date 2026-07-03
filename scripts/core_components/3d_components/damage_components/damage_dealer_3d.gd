@icon("uid://b1tkukgoalsin")
class_name DamageDealer3D
extends Area3D
## A generic 3D damage source designed to interact with [DamageReceiver3D].
##
## Attach this to projectiles, melee weapons, or environmental hazards.
## It acts as a passive data container for combat interactions.

# SIGNALS
signal hit_landed(receiver: DamageReceiver3D) ## Emitted when this DamageDealer successfully damages a DamageReceiver.
signal terrain_hit ## Emitted when the dealer hits solid scenery.

# ENUMS
enum Team { PLAYER, ENEMY, NEUTRAL, CUSTOM }

# EXPORT VARIABLES
@export_group("Combat Stats")
@export_subgroup("Damage")
@export var damage_amount: int = 1 ## The base damage value of this attack.
@export var damage_type: String = "" ## The elemental or physical category of this damage.

@export_subgroup("Team")
@export var team: Team = Team.PLAYER ## The team this attack belongs to.
@export var custom_team: String = "" ## The custom team name to use.

@export_subgroup("Modifiers")
@export var modifiers: Array[DamageModifier] = [] ## Array of active damage modifiers applied before hitting.

@export_group("On Hit")
@export var disable_on_hit: bool = false ## If true, disables monitoring and monitorable after a hit.

@export_group("Physics Config")
@export_flags_3d_physics var combat_physics_layer: int = 4 ## The physics layer reserved for DamageDealer/DamageReceiver interactions.
@export var collide_with_terrain: bool = false
@export_flags_3d_physics var terrain_physics_layer: int = 1 ## The physics layer your solid scenery is on.

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_setup_physics_collision()
	_sort_modifiers()

# PUBLIC FUNCTIONS
func confirm_hit(receiver: DamageReceiver3D) -> void:
	## Called by the DamageReceiver3D to confirm damage was applied.
	hit_landed.emit(receiver)
	if disable_on_hit:
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)

func get_modified_damage() -> int:
	## Calculates final damage after applying all modifiers.
	var final_amount: int = damage_amount
	for mod in modifiers:
		final_amount = mod.modify_damage(final_amount, damage_type)
		if final_amount <= 0:
			return 0
	return final_amount

# PRIVATE FUNCTIONS
func _setup_physics_collision() -> void:
	# 1. Reset current collision settings
	collision_layer = 0
	collision_mask = 0

	# 2. Set Monitoring (Passive Object)
	monitoring = collide_with_terrain
	monitorable = true

	# 3. Set the Layer (Where we exist)
	collision_layer |= combat_physics_layer
	
	if collide_with_terrain:
		collision_mask |= terrain_physics_layer
		body_entered.connect(_on_body_entered)
	else:
		collision_mask &= ~terrain_physics_layer

func _sort_modifiers() -> void:
	modifiers.sort_custom(func(a, b): return a.priority > b.priority)

func _on_body_entered(_body: Node3D) -> void:
	terrain_hit.emit()
