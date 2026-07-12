class_name WeaponManagerComponent extends Node
## Manages the player's weapon inventory and input routing.
##
## This component handles instantiating the correct weapon scene into the WeaponRig and
## passing the AmmoComponent via dependency injection. It receives commands from external
## input scripts (like PlayerWeaponInput or AI).

# SIGNALS
signal weapon_switched(weapon_resource: FPSWeaponData, weapon_node: BaseWeapon) ## Emitted when the active weapon changes.

# EXPORT VARIABLES
@export_group("Component References")
@export var weapon_rig: Node3D ## The anchor node (WeaponRig) where weapons are instantiated.
@export var ammo_component: AmmoComponent ## The player's reserve ammo pool.
@export var player_camera: FPSCameraViewfinder

@export_group("Inventory")
@export var starting_weapons: Array[FPSWeaponData] = [] ## The list of weapons the player spawns with.

# PRIVATE VARIABLES
var _unlocked_weapons: Array[FPSWeaponData] = []
var _current_weapon_index: int = 0
var _active_weapon_node: BaseWeapon = null
var _is_changing_weapon: bool = false
var _saved_clips: Dictionary[FPSWeaponData, int] = {}


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_unlocked_weapons = starting_weapons.duplicate()
	
	if _unlocked_weapons.size() > 0:
		equip_weapon.call_deferred(0)


# PUBLIC FUNCTIONS
func pull_trigger() -> void: ## Passes the fire command to the active weapon.
	if is_instance_valid(_active_weapon_node) and not _is_changing_weapon:
		_active_weapon_node.pull_trigger()


func release_trigger() -> void: ## Passes the release command to the active weapon.
	if is_instance_valid(_active_weapon_node):
		_active_weapon_node.release_trigger()


func reload() -> void: ## Passes the reload command and ammo pool to the active weapon.
	if is_instance_valid(_active_weapon_node) and not _is_changing_weapon:
		_active_weapon_node.reload(ammo_component)


func cycle_next() -> void: ## Switches to the next weapon in the inventory.
	if not _is_changing_weapon:
		_cycle_weapon(1)


func cycle_prev() -> void: ## Switches to the previous weapon in the inventory.
	if not _is_changing_weapon:
		_cycle_weapon(-1)


func equip_weapon(index: int) -> void: ## Instantiates a weapon from the inventory and makes it active.
	if index < 0 or index >= _unlocked_weapons.size() or _is_changing_weapon:
		push_warning("WeaponManager: Invalid weapon index.")
		return
	if is_instance_valid(_active_weapon_node):
		if _active_weapon_node.current_state == BaseWeapon.WeaponState.RELOADING:
			return
	_is_changing_weapon = true
		
	# 1. Clean up the old weapon if one exists
	if is_instance_valid(_active_weapon_node):
		_active_weapon_node.release_trigger() # Safety: Stop firing before swapping
		var old_weapon_data = _unlocked_weapons[_current_weapon_index]
		_saved_clips[old_weapon_data] = _active_weapon_node.current_clip
		
		_active_weapon_node.unequip()
		await _active_weapon_node.unequip_finished
		if is_instance_valid(_active_weapon_node): # Double-check it wasn't deleted during the wait
			_active_weapon_node.queue_free()
		
	_current_weapon_index = index
	var new_weapon_data: FPSWeaponData = _unlocked_weapons[_current_weapon_index]
	
	# 2. Safety check the resource
	if not new_weapon_data or not new_weapon_data.weapon_scene:
		push_error("WeaponManager: WeaponResource is missing or has no packed scene.")
		return
		
	# 3. Instantiate the new weapon prefab
	var spawned_weapon = new_weapon_data.weapon_scene.instantiate()
	
	if not spawned_weapon is BaseWeapon:
		push_error("WeaponManager: Spawned scene does not have a BaseWeapon root script.")
		spawned_weapon.queue_free()
		return
		
	_active_weapon_node = spawned_weapon as BaseWeapon
	
	# 4. Inject the data into the weapon shell so it knows its stats
	var starting_clip = _saved_clips.get(new_weapon_data, -1)
	_active_weapon_node.initialize_weapon(new_weapon_data, starting_clip, player_camera)
	
	# 5. Parent it to the WeaponRig (This applies all your sway/bob/tilt automatically)
	if is_instance_valid(weapon_rig):
		weapon_rig.add_child(_active_weapon_node)
		
	weapon_switched.emit(new_weapon_data, _active_weapon_node)
	await _active_weapon_node.equip_finished
	
	_is_changing_weapon = false


func give_weapon(new_weapon: FPSWeaponData) -> void: ## Adds a new weapon to the inventory.
	if not _unlocked_weapons.has(new_weapon):
		_unlocked_weapons.append(new_weapon)
		# Optionally auto-equip the new weapon here
		equip_weapon(_unlocked_weapons.size() - 1)


func aim_down() -> void:
	if is_instance_valid(_active_weapon_node) and not _is_changing_weapon:
		_active_weapon_node.aim_down()


func stop_aiming() -> void:
	if is_instance_valid(_active_weapon_node):
		_active_weapon_node.stop_aiming()


# PRIVATE FUNCTIONS
func _cycle_weapon(direction: int) -> void: # Handles wrapping around the inventory array.
	if _unlocked_weapons.size() <= 1:
		return
		
	var next_index := _current_weapon_index + direction
	
	# Wrap around logic
	if next_index >= _unlocked_weapons.size():
		next_index = 0
	elif next_index < 0:
		next_index = _unlocked_weapons.size() - 1
		
	equip_weapon(next_index)
