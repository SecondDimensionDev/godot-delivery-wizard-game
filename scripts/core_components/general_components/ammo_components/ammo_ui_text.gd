@icon("uid://cb168okhds4m2") # Reusing your UI icon!
class_name AmmoUIText
extends Control
## Displays weapon and ammo data using standard Label nodes.
##
## Connects to the WeaponManager to track weapon swapping, and listens
## to the active weapon and AmmoComponent to update clip and reserve text.

# EXPORT VARIABLES
@export_group("Data Sources")
@export var weapon_manager: WeaponManagerComponent ## The player's WeaponManagerComponent.
@export var ammo_component: AmmoComponent ## The player's main reserve ammo pool.

@export_group("Labels")
@export var label_weapon_name: Label ## Displays the name of the active weapon.
@export var label_clip: Label ## Displays the ammo currently loaded in the gun.
@export var label_reserve: Label ## Displays the total reserve ammo in the player's pockets.

# PRIVATE VARIABLES
var _active_weapon: BaseWeapon
var _active_ammo_type: String = ""

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_initial_setup.call_deferred()

# PRIVATE FUNCTIONS
func _on_weapon_switched(weapon_data: FPSWeaponData, weapon_node: BaseWeapon) -> void:
	# 1. Disconnect the old weapon's signal so we don't listen to a gun in our pocket
	if is_instance_valid(_active_weapon) and _active_weapon.clip_changed.is_connected(_on_clip_changed):
		_active_weapon.clip_changed.disconnect(_on_clip_changed)
		
	_active_weapon = weapon_node
	_active_ammo_type = weapon_data.ammo_type
	
	# 2. Connect the new weapon's signal
	if is_instance_valid(_active_weapon):
		_active_weapon.clip_changed.connect(_on_clip_changed)
		_update_clip_text(_active_weapon.current_clip)
		
	# 3. Update the UI for the new weapon
	if label_weapon_name:
		label_weapon_name.text = weapon_data.weapon_name
		
	_update_reserve_text(ammo_component.get_ammo(_active_ammo_type))

func _on_clip_changed(new_amount: int) -> void: 
	_update_clip_text(new_amount)

func _on_reserve_changed(type: String, new_amount: int) -> void: 
	# Only update the text if the ammo that changed is the ammo we are currently using
	if type == _active_ammo_type:
		_update_reserve_text(new_amount)

func _update_clip_text(amount: int) -> void: 
	if label_clip:
		label_clip.text = str(amount)

func _update_reserve_text(amount: int) -> void: 
	if label_reserve:
		label_reserve.text = str(amount)

func _initial_setup() -> void:
	if is_instance_valid(weapon_manager):
		weapon_manager.weapon_switched.connect(_on_weapon_switched)
		
	if is_instance_valid(ammo_component):
		ammo_component.ammo_changed.connect(_on_reserve_changed)
