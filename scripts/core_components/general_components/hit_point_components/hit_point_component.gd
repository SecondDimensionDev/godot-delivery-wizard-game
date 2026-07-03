@icon("uid://bc20w7r04vkes")
class_name HitPointComponent
extends Node

## Manages hit points, damage calculation, and destruction or death state.
##
## This component acts as the "vitality" system for any entity (Unit, Destructible Wall, Player).
## It handles value clamping, invulnerability windows, and logic for destroying or killing the entity.[br]
## There is also a modifier mechanic that uses any resources extended from [HitPointModifiers].[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add as a child node to any entity.[br]
## 2. Connect to the [signal hp_depleted] signal to handle entity destruction (queue_free, animations, etc).[br]
## 3. Connect to [signal hp_changed] to update UI bars.[br]
## 4. Call [method damage] or [method heal] from external scripts (like weapons or projectiles).[br]
## 5. Add instances of [HitPointModifier] to the modifiers array to apply them.

# SIGNALS

signal hp_changed(hp_data: Dictionary) ## Emitted whenever HP value changes.
signal damaged(amount: int) ## Emitted specifically when damage is taken.
signal healed(amount: int) ## Emitted specifically when HP is restored.
signal hp_depleted ## Emitted when HP reaches zero.
signal revived ## Emitted when the entity was revived (after their HP was fully depeleted)
signal invulnerability_changed(is_active: bool) ## Emitted when invulnerability starts or ends.
signal damage_blocked_by_invulnerability ## Emitted when damage is blocked
signal max_hp_increased_permanently(amount: int) ## Emitted when max HP is increased permanently.
signal max_hp_increased_temporarily(amount: int) ## Emitted when a temporary increase in max is added.
signal temporary_max_hp_expired(amount: int) ## Emitted when a temporary increase in max has expired.
signal modifier_value_changed(modifier_name: String, new_value: float) ## Emitted when a modifier reports a value change.

# EXPORT VARIABLES

@export_group("Configuration")
@export var max_hp: int = 100 ## The maximum hit points allowed.
@export var start_at_max: bool = true ## If true, current HP starts at max_hp.
@export var can_be_healed: bool = true ## If true the entity's HP can be healed, if false healing has no effect
@export var allow_overheal: bool = false ## If true, healing can exceed max_hp.
@export var revive_on_heal: bool = false ## If true, entities with no HP can be resurrected when healed

@export_group("Invulnerability")
@export var invulnerable_after_damage: bool = false ## Should entity become invulnerable for a period after taking damage
@export var invulnerability_time: float = 0.2 ## Duration of immunity after taking damage. A value of 0 will have not effect

@export_group("Modifiers")
@export var modifiers: Array[HitPointModifier] = [] ## An array of active hit point modifiers.

# PUBLIC VARIABLES

var current_hp: int = 0 ## The current amount of hit points.
var is_hp_depleted: bool = false ## State flag to prevent interactions after death.
var is_invulnerable: bool = false ## State flag for temporary immunity.

# PRIVATE VARIABLES

var _invuln_timer: Timer
var _bonus_max_hp: int = 0 # Tracks temporary boosts to Max HP.

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	if start_at_max:
		current_hp = max_hp
	else:
		current_hp = 0
	
	_setup_invulnerability_timer()
	call_deferred("_handle_hp_change", 0, 0)


# PUBLIC FUNCTIONS

func damage(dmg_amount: int, damage_type: String = "") -> void: ## Reduces HP by amount, respecting invulnerability.
	
	var amount: int = _calculate_modified_value(dmg_amount, true, damage_type)
	
	if is_hp_depleted or amount <= 0:
		return
	
	if is_invulnerable:
		damage_blocked_by_invulnerability.emit()
		return
	
	var old_hp := current_hp
	current_hp = clampi(current_hp - amount, 0, get_visual_max_hp())
	
	var hp_diff := current_hp - old_hp # will be negative or 0
	damaged.emit(amount)
	_handle_hp_change(hp_diff, 0)
	
	if current_hp <= 0:
		_set_hp_depleted()
	else:
		if invulnerable_after_damage:
			_start_invulnerability(invulnerability_time)


func heal(heal_amount: int) -> void: ## Restores HP by amount.
	
	var amount: int = _calculate_modified_value(heal_amount, false)
	
	if not can_be_healed:
		return
	
	var hp_to_restore: int = amount
	
	if not allow_overheal:
		hp_to_restore = min((get_total_max_hp() - current_hp), amount)
	
	if hp_to_restore <= 0:
		return
	
	if is_hp_depleted and current_hp <= 0:
		if revive_on_heal:
			is_hp_depleted = false
			current_hp = 0
			revived.emit()
		else:
			return
	
	current_hp += hp_to_restore
	
	healed.emit(hp_to_restore)
	_handle_hp_change(hp_to_restore, 0) #TODO What about over-heal affecting max hp?


func set_max_hp(amount: int, set_current_hp_to_max: bool = false) -> void: ## Updates max HP cap.
	if amount < 1:
		push_warning("hpComponent: Max hp cannot be less than 1.")
		return
	
	var old_max = max_hp
	max_hp = amount
	var diff_max = max_hp - old_max
	
	if diff_max > 0:
		max_hp_increased_permanently.emit(diff_max)
	
	var diff_current = 0
	
	if set_current_hp_to_max:
		var old_curr = current_hp
		current_hp = get_total_max_hp()
		diff_current = current_hp - old_curr
	elif current_hp > get_total_max_hp() and not allow_overheal:
		# We need to clamp, so we calculate that diff manually here
		var limit = get_total_max_hp()
		var old_curr = current_hp
		current_hp = limit
		diff_current = current_hp - old_curr
	
	_handle_hp_change(diff_current, diff_max)


func add_temporary_max_hp(amount: int, duration: float, scale_up_hp: bool = false, set_current_hp_to_max: bool = false) -> void: ## Adds temporary max HP for the specified duration.
	if amount == 0 or duration <= 0: return
	
	_bonus_max_hp += amount
	
	max_hp_increased_temporarily.emit(amount)
	
	var diff_current = 0
	var diff_max = amount # We just added this amount
	
	# Apply immediate effects
	if set_current_hp_to_max:
		var previous_hp = current_hp
		current_hp = get_total_max_hp()
		diff_current = current_hp - previous_hp
	elif scale_up_hp:
		current_hp += amount
		diff_current = amount
	
	_handle_hp_change(diff_current, diff_max)
	
	# Create a self-contained timer sequence
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func(): _remove_temporary_max_hp(amount))


func remove_all_hp() -> void: ## Instantly reduces HP to zero and sets the entity's HP as depleted.
	if is_hp_depleted:
		return
	
	var damage_amount = current_hp
	current_hp = 0
	_handle_hp_change(-damage_amount, 0)
	_set_hp_depleted()


func revive(percent_hp: float = 1.0, specific_hp: int = 0) -> void: ## Resets depleted state and restores HP.
	if not is_hp_depleted:
		return
	
	if percent_hp == 0.0 and specific_hp == 0:
		return
	
	is_hp_depleted = false
	specific_hp = clampi(specific_hp,1,max_hp)
	
	var percent_target_hp: int = int(float(max_hp) * clampf(percent_hp, 0.0, 1.0))
	
	var target_hp: int = maxi(percent_target_hp, specific_hp)
	
	current_hp = target_hp
	
	_handle_hp_change(target_hp, 0)
	revived.emit()


func set_invulnerablility(invulnerable: bool, duration: float = 0.0) -> void: ## Manually sets invulnerable state. Duration of 0 will fallback to default duration
	if invulnerable:
		var time = duration if duration > 0.0 else invulnerability_time
		_start_invulnerability(time)
	else:
		if is_invulnerable:
			_stop_invulnerability()


func get_total_max_hp() -> int: ## Returns Base Max HP + Temporary Bonuses.
	return max_hp + _bonus_max_hp


func get_visual_max_hp() -> int: ## Returns the highest value between Current and Total Max. Use this for UI bars.
	return maxi(current_hp, get_total_max_hp())


func add_modifier(modifier: HitPointModifier) -> void: ## Adds a new modifier from the HitPointModifier class, to modify damage or healing.
	if not modifier in modifiers:
		modifier.setup(self)
		modifiers.append(modifier)
		# Sort by priority (descending) so high priority executes first
		modifiers.sort_custom(func(a, b): return a.priority > b.priority)


func remove_modifier_by_reference(modifier: HitPointModifier) -> void: ## Removes a [HitPointModifier] from the modifiers array using its direct reference.
	modifiers.erase(modifier)


func remove_modifier_by_name(modifier_name: String) -> void: ## Removes a [HitPointModifier] from the modifiers array using its unique string modifier name.
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].modifier_name == modifier_name:
			modifiers.remove_at(i)


func remove_modifier_by_class(target_class) -> void: ## Removes any [HitPointModifier] from the modifiers array of the specified class.
	for i in range(modifiers.size() - 1, -1, -1):
		if is_instance_of(modifiers[i], target_class):
			modifiers.remove_at(i)


func report_modifier_value(modifier_name: String, value: float) -> void: ## Allows modifiers to broadcast their status to UI elements.
	modifier_value_changed.emit(modifier_name, value)


# PRIVATE FUNCTIONS

func _handle_hp_change(diff_current: int, diff_max: int) -> void:
	# 1. Calculate the complex breakdowns
	var total_max = get_total_max_hp()
	
	# Standard HP is your health "inside" the bar (not overheal)
	var standard_hp = clampi(current_hp, 0, total_max)
	
	# Overheal is anything "sticking out" above the max
	var overheal_hp = maxi(0, current_hp - total_max)
	
	# 2. Pack it into a Dictionary
	var data = {
		"total_current_hp": current_hp,
		"diff_current_hp": diff_current,
		"diff_max_hp": diff_max,
		"base_max_hp": max_hp,
		"temp_max_hp": _bonus_max_hp,
		"total_max_hp": total_max,
		"effective_max_hp" : get_visual_max_hp(),
		"standard_hp": standard_hp,
		"overhealed_hp": overheal_hp
	}
	
	hp_changed.emit(data)


func _set_hp_depleted() -> void: # Handles internal death logic.
	current_hp = 0
	is_hp_depleted = true
	hp_depleted.emit()


func _setup_invulnerability_timer() -> void: # Creates a local timer for i-frames.
	_invuln_timer = Timer.new()
	_invuln_timer.one_shot = true
	_invuln_timer.wait_time = invulnerability_time
	_invuln_timer.timeout.connect(_stop_invulnerability)
	add_child(_invuln_timer)


func _start_invulnerability(duration: float) -> void: # Activates i-frames.
	if duration <= 0: return
	
	if not _invuln_timer:
		_setup_invulnerability_timer()
	
	is_invulnerable = true
	invulnerability_changed.emit(true)
	_invuln_timer.start(duration)


func _stop_invulnerability() -> void:
	is_invulnerable = false
	invulnerability_changed.emit(false)
	if _invuln_timer and not _invuln_timer.is_stopped():
		_invuln_timer.stop()


func _remove_temporary_max_hp(amount: int) -> void:
	_bonus_max_hp -= amount
	
	temporary_max_hp_expired.emit(amount)
	
	var diff_max = -amount
	var diff_current = 0
	
	# Clamp logic if we shrink below current HP
	if not allow_overheal:
		var limit = get_total_max_hp()
		if current_hp > limit:
			diff_current = limit - current_hp # This will be negative
			current_hp = limit
	
	_handle_hp_change(diff_current, diff_max)


func _calculate_modified_value(amount: int, is_damage: bool, damage_type: String = "") -> int: # Routes values through active modifiers
	var final_amount = amount
	for mod in modifiers:
		if is_damage:
			final_amount = mod.modify_damage(final_amount, damage_type)
		else:
			final_amount = mod.modify_heal(final_amount)
			
		if final_amount <= 0:
			return 0
			
	return final_amount
