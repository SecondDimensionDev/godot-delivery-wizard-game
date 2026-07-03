class_name BaseWeapon
extends Node3D
## The core physical controller for all weapons.

# SIGNALS
signal fired 
signal clip_changed(new_amount: int) 
signal reload_started 
signal reload_finished 
signal out_of_ammo
signal equip_finished
signal unequip_finished ## Emitted so the Manager knows it is safe to swap

# ENUMS
enum WeaponState {
	EQUIPPING,
	IDLE,
	FIRING,
	RELOADING,
	UNEQUIPPING
}

# PUBLIC VARIABLES
var weapon_data: FPSWeaponData 
var current_clip: int = 0 
var current_state: WeaponState = WeaponState.IDLE

# EXPORT VARIABLES
@export_group("Component References")
@export var fire_behavior: Node3D 
@export var anim_player: AnimationPlayer
@export var debug_objects: Node3D
@export var ads_component: FPSWeaponADSComponent


# PRIVATE VARIABLES
var _fire_timer: Timer
var _is_trigger_held: bool = false
var _bursts_fired: int = 0

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_setup_fire_timer()
	if debug_objects and is_instance_valid(debug_objects):
		debug_objects.queue_free()


func initialize_weapon(data: FPSWeaponData, saved_clip: int = -1, camera: FPSCameraViewfinder = null) -> void: 
	weapon_data = data
	if saved_clip >= 0:
		current_clip = saved_clip
	else:
		current_clip = weapon_data.clip_size
		
	if is_instance_valid(ads_component) and is_instance_valid(camera):
		ads_component.camera_viewfinder = camera
		
	equip() # Automatically play the equip animation when spawned


# PUBLIC FUNCTIONS
func equip() -> void: ## Plays the equip animation before allowing the gun to fire.
	current_state = WeaponState.EQUIPPING
	
	if is_instance_valid(anim_player) and anim_player.has_animation("equip"):
		var anim_speed: float = 1.0 / weapon_data.equip_time
		anim_player.play("equip", -1.0, anim_speed) 
		anim_player.advance(0) 
		await anim_player.animation_finished
		
	current_state = WeaponState.IDLE
	equip_finished.emit()


func unequip() -> void: ## Plays the unequip animation and signals when done.
	if current_state == WeaponState.UNEQUIPPING:
		return
		
	current_state = WeaponState.UNEQUIPPING
	
	if is_instance_valid(anim_player) and anim_player.has_animation("unequip"):
		var anim_speed: float = 1.0 / weapon_data.unequip_time
		
		# Play the animation with the custom speed
		anim_player.play("unequip", -1.0, anim_speed) 
		await anim_player.animation_finished
		
	unequip_finished.emit()

func pull_trigger() -> void: ## Call this when the player presses the fire button
	_is_trigger_held = true
	if current_state == WeaponState.IDLE:
		_attempt_fire()

func release_trigger() -> void: ## Call this when the player releases the fire button
	_is_trigger_held = false


#func primary_fire() -> void: 
	## The weapon can ONLY fire if it is completely IDLE
	#if current_state != WeaponState.IDLE or not is_instance_valid(weapon_data):
		#return
		#
	#if current_clip <= 0:
		#out_of_ammo.emit()
		#return
		#
	#current_state = WeaponState.FIRING
	#current_clip -= 1
	#clip_changed.emit(current_clip)
	#fired.emit()
	#
	#_fire_timer.start(weapon_data.fire_rate)
	#
	#if is_instance_valid(anim_player) and anim_player.has_animation("fire"):
		#var anim_speed: float = 1.0 / weapon_data.fire_rate
		#anim_player.play("fire")
		#anim_player.play("fire", -1.0, anim_speed)
		#
	#if is_instance_valid(fire_behavior) and fire_behavior.has_method("fire"):
		#fire_behavior.fire(weapon_data)


func reload(ammo_component: Node) -> void: 
	# The weapon can ONLY reload if it is completely IDLE
	if current_state != WeaponState.IDLE or current_clip == weapon_data.clip_size or not is_instance_valid(weapon_data):
		return
		
	if ammo_component.get_ammo(weapon_data.ammo_type) <= 0:
		return
		
	current_state = WeaponState.RELOADING
	reload_started.emit()
	
	if is_instance_valid(anim_player) and anim_player.has_animation("reload"):
		# Retrieve actual animation length in seconds
		var anim_length: float = anim_player.get_animation("reload").length
		
		# Calculate the playback speed needed to match the weapon's reload stat
		var anim_speed: float = anim_length / weapon_data.reload_speed
		
		anim_player.play("reload", -1.0, anim_speed)
		await anim_player.animation_finished
	
	_process_reload_math(ammo_component)
	
	current_state = WeaponState.IDLE
	reload_finished.emit()


func aim_down() -> void:
	if is_instance_valid(ads_component) and current_state != WeaponState.RELOADING:
		ads_component.aim_down()


func stop_aiming() -> void:
	if is_instance_valid(ads_component):
		ads_component.stop_aiming()


# PRIVATE FUNCTIONS
func _attempt_fire() -> void:
	# The weapon can ONLY initiate a fire sequence if IDLE 
	if current_state != WeaponState.IDLE or not is_instance_valid(weapon_data):
		return
	
	if current_clip <= 0:
		out_of_ammo.emit()
		return
	
	current_state = WeaponState.FIRING
	_bursts_fired = 0
	
	_execute_shot()


func _execute_shot() -> void:
	current_clip -= 1
	clip_changed.emit(current_clip)
	fired.emit()
	
	# 1. Determine the correct delay for THIS specific shot
	var current_delay: float = weapon_data.fire_rate
	if weapon_data.fire_mode == FPSWeaponData.FireMode.BURST and _bursts_fired < weapon_data.burst_count - 1:
		current_delay = weapon_data.burst_rate
	
	# 2. Fix the animation bug
	if is_instance_valid(anim_player) and anim_player.has_animation("fire"):
		# Force the player to stop so it can instantly restart the burst animation
		anim_player.stop() 
		
		var anim_length: float = anim_player.get_animation("fire").length
		
		# Calculate the playback speed needed to match the weapon's fire rate stat
		var anim_speed: float = anim_length / current_delay
		
		anim_player.play("fire", -1.0, anim_speed)
	
	if is_instance_valid(fire_behavior) and fire_behavior.has_method("fire"):
		fire_behavior.fire(weapon_data)
	
	# 3. Start the timer with the correct delay
	_fire_timer.start(current_delay)


func _setup_fire_timer() -> void: # Complex state evaluation happens when the timer finishes
	_fire_timer = Timer.new()
	_fire_timer.one_shot = true
	
	_fire_timer.timeout.connect(func():
		if current_state != WeaponState.FIRING:
			return
			
		# Handle Burst Continuations
		if weapon_data.fire_mode == FPSWeaponData.FireMode.BURST and _bursts_fired < weapon_data.burst_count - 1:
			if current_clip > 0:
				_bursts_fired += 1
				_execute_shot()
				return
			else:
				out_of_ammo.emit()
	
		# Sequence finished, return to IDLE
		current_state = WeaponState.IDLE
	
		# If Automatic and trigger is still squeezed, loop back instantly
		if _is_trigger_held and weapon_data.fire_mode == FPSWeaponData.FireMode.AUTOMATIC:
			_attempt_fire()
	)
	add_child(_fire_timer)


func _process_reload_math(ammo_component: Node) -> void: 
	var amount_needed: int = weapon_data.clip_size
	if not weapon_data.discard_clip_on_reload:
		amount_needed -= current_clip
		
	var ammo_received: int = ammo_component.consume_ammo(weapon_data.ammo_type, amount_needed)
	
	if weapon_data.discard_clip_on_reload:
		current_clip = ammo_received
	else:
		current_clip += ammo_received
		
	clip_changed.emit(current_clip)
