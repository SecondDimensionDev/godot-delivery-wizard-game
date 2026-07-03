@icon("uid://dowlruklvrw57")
class_name DamageReceiver3D
extends Area3D
## A detection zone that accepts damage from [DamageDealer3D] Components.
##
## This component requires a child CollisionShape3D. It actively monitors for any
## overlapping [DamageDealer3D] on the specified physics layer. When a valid hit is
## detected, it validates the team and applies damage to the linked [HitPointComponent].

# SIGNALS
signal hit_received(damage_amount: int, source: Node) ## Emitted when damage is successfully received.

# ENUMS
enum Team { PLAYER, ENEMY, NEUTRAL, CUSTOM }

# EXPORT VARIABLES
@export_group("References")
@export var hit_point_component: HitPointComponent ## The component that tracks vitality.

@export_group("Damage Settings")
@export var damage_multiplier: float = 1.0 ## Multiplies incoming damage (e.g., 2.0 for weak spots).
@export var take_friendly_fire: bool = false

@export_group("Team Configuration")
@export var team: Team = Team.ENEMY ## The team this entity belongs to.
@export var custom_team: String = ""

@export_group("Physics Config")
@export_flags_3d_physics var combat_physics_layer: int = 4 ## The physics layer reserved for DamageDealer/DamageReceiver interactions.

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_setup_physics_collision()
	area_entered.connect(_on_area_entered)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not hit_point_component:
		warnings.append("This DamageReceiver3D requires a HitPointComponent to function.")
	return warnings

# PRIVATE FUNCTIONS
func _setup_physics_collision() -> void:
	# 1. Reset current collision settings to avoid Inspector mistakes
	collision_layer = 0
	collision_mask = 0

	# 2. Set Monitoring (Active Scanner)
	monitoring = true
	monitorable = true 

	# 3. Set the Mask (What we look for)
	collision_mask |= combat_physics_layer

	# 4. Set the Layer (Where we exist)
	collision_layer |= combat_physics_layer

func _on_area_entered(area: Area3D) -> void:
	# Strict typing check to ignore random triggers or standard physics bodies
	if not area is DamageDealer3D:
		return

	var damage_dealer: DamageDealer3D = area

	# Negate Friendly Fire
	if not take_friendly_fire:
		if damage_dealer.team == team:
			if not team == Team.CUSTOM:
				return
			else:
				if damage_dealer.custom_team == custom_team:
					return

	# Retrieve the final calculated damage from the dealer
	var incoming_damage: int = damage_dealer.get_modified_damage()
	var final_damage: int = int(incoming_damage * damage_multiplier)

	if hit_point_component:
		# Pass the damage type along to the hit point component
		hit_point_component.damage(final_damage, damage_dealer.damage_type)
		
	hit_received.emit(final_damage, damage_dealer)
	damage_dealer.confirm_hit(self)
