@icon("uid://n066lq3docl5")
class_name TopDownMoveTargeter
extends Node

# ENUMS
enum TargetMode {PLAYER_POSITION, GROUP_POSITION, OBJECT_POSITION, CUSTOM_POSITION, MOUSE_CURSOR}
enum UpdateMode {IDLE_PROCESS, PHYSICS_PROCESS}

# EXPORT VARIABLES
@export_group("Configuration")
@export var component_parent: Node2D
@export var targeting_enabled: bool = true
@export var targeting_mode: TargetMode = TargetMode.CUSTOM_POSITION
@export var thinking_time: float = 0.0 ## Thinking time in seconds between updates. Set to 0 to update every frame.

@export_group("Target Settings")
@export_subgroup("Target Player Settings")
@export var player_group: String = "player"

@export_subgroup("Target Group Settings")
@export var custom_group: String = ""
@export var pick_random_instance: bool = false

@export_subgroup("Target Object Settings")
@export var target_object: Node2D

@export_subgroup("Target Position Settings")
@export var target_position: Vector2

@export_group("Arrival Settings")
@export var register_arrival: bool = false
@export var arrival_distance: float = 2.0 ## The distance in pixels considered "arrived".

@export_group("Process Thread")
@export var update_mode: UpdateMode = UpdateMode.PHYSICS_PROCESS

# PUBLIC VARIABLES
var has_arrived: bool = false ## True if the parent is within the arrival_distance of the target.

# PRIVATE VARIABLES	
var _player_reference: Node2D
var _group_reference: Node2D
var _delay_timer: float = 0.0 # Tracks time passed since last update


# VIRTUAL BUILT-IN FUNCTIONS
func _ready() -> void:
	if not is_instance_valid(component_parent):
		if get_parent() is Node2D:
			component_parent = get_parent()
		else:
			targeting_enabled = false
		push_warning("No Component Parent Assigned")
	
	if update_mode == UpdateMode.IDLE_PROCESS:
		set_physics_process(false)
	else:
		set_process(false)
	
	acquire_target()


func _process(delta: float) -> void:
	_handle_update_timer(delta)


func _physics_process(delta: float) -> void:
	_handle_update_timer(delta)


# PUBLIC FUNCTIONS
func acquire_target() -> void:
	_apply_fallback_position()
	register_arrival = false
	
	if targeting_mode == TargetMode.PLAYER_POSITION:
		_get_player_reference()
	
	if targeting_mode == TargetMode.GROUP_POSITION:
		_get_group_reference()


# PRIVATE FUNCTIONS
func _handle_update_timer(delta: float) -> void: # Handles the thinking time delay.
	if thinking_time <= 0.0:
		_update_targeting()
		return
		
	_delay_timer += delta
	if _delay_timer >= thinking_time:
		_delay_timer = 0.0
		_update_targeting()


func _update_targeting() -> void:
	if targeting_mode == TargetMode.CUSTOM_POSITION:
		return
	
	if not targeting_enabled:
		_apply_fallback_position()
		return
	
	match targeting_mode:
		TargetMode.PLAYER_POSITION:
			_update_target_to_player_position()
		TargetMode.GROUP_POSITION:
			_update_target_to_player_position()
		TargetMode.OBJECT_POSITION:
			_update_target_to_object_position()
		TargetMode.MOUSE_CURSOR:
			_update_target_to_mouse_position()
	
	if register_arrival:
		_check_arrival()


func _update_target_to_player_position() -> void:
	if is_instance_valid(_player_reference):
		target_position = _player_reference.global_position
	else:
		_apply_fallback_position()


func _update_target_to_group_position() -> void:
	if is_instance_valid(_group_reference):
		target_position = _group_reference.global_position
	else:
		_apply_fallback_position()


func _update_target_to_object_position() -> void:
	if is_instance_valid(target_object):
		target_position = target_object.global_position
	else:
		_apply_fallback_position()


func _update_target_to_mouse_position() -> void:
	if is_instance_valid(component_parent):
		target_position = component_parent.get_global_mouse_position()
	else:
		_apply_fallback_position()


func _get_player_reference() -> void:
	_player_reference = get_tree().get_first_node_in_group(player_group)


func _get_group_reference() -> void:
	if pick_random_instance:
		var group_nodes = get_tree().get_nodes_in_group(custom_group)
			
		if not group_nodes.is_empty():
			var random_node = group_nodes.pick_random()
			_group_reference = random_node
	else:
		_group_reference = get_tree().get_first_node_in_group(custom_group)


func _check_arrival() -> void: # Checks if the parent is within the arrival distance.
	if is_instance_valid(component_parent):
		var dist = component_parent.global_position.distance_to(target_position)
		has_arrived = dist <= arrival_distance
	else:
		has_arrived = false


func _apply_fallback_position() -> void:
	if is_instance_valid(component_parent):
		target_position = component_parent.global_position
