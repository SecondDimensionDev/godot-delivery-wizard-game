@icon("uid://n066lq3docl5") 
class_name TopDownMoveTargeter3D 
extends Node
## Locates and exposes a target Vector3 position for AI controllers.

# ENUMS
enum TargetMode {PLAYER_POSITION, GROUP_POSITION, OBJECT_POSITION, CUSTOM_POSITION}

# EXPORT VARIABLES
@export_group("Configuration")
@export var component_parent: Node3D
@export var targeting_enabled: bool = true
@export var targeting_mode: TargetMode = TargetMode.PLAYER_POSITION
@export var thinking_time: float = 0.1 ## Thinking time in seconds between updates.

@export_group("Target Settings")
@export var player_group: String = "player"
@export var custom_group: String = ""
@export var target_object: Node3D
@export var target_position: Vector3

@export_group("Arrival Settings")
@export var register_arrival: bool = false
@export var arrival_distance: float = 2.0

# PUBLIC VARIABLES
var has_arrived: bool = false

# PRIVATE VARIABLES
var _player_reference: Node3D
var _group_reference: Node3D
var _delay_timer: float = 0.0

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not is_instance_valid(component_parent):
		if get_parent() is Node3D:
			component_parent = get_parent()
		else:
			targeting_enabled = false
			
	acquire_target()

func _physics_process(delta: float) -> void:
	_handle_update_timer(delta)

# PUBLIC FUNCTIONS
func acquire_target() -> void:
	_apply_fallback_position()
	register_arrival = false

	if targeting_mode == TargetMode.PLAYER_POSITION:
		_get_player_reference()
	elif targeting_mode == TargetMode.GROUP_POSITION:
		_get_group_reference()

# PRIVATE FUNCTIONS
func _handle_update_timer(delta: float) -> void:
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
			if is_instance_valid(_player_reference):
				target_position = _player_reference.global_position
			else:
				_apply_fallback_position()
		TargetMode.GROUP_POSITION:
			if is_instance_valid(_group_reference):
				target_position = _group_reference.global_position
			else:
				_apply_fallback_position()
		TargetMode.OBJECT_POSITION:
			if is_instance_valid(target_object):
				target_position = target_object.global_position
			else:
				_apply_fallback_position()

	if register_arrival:
		_check_arrival()

func _get_player_reference() -> void:
	_player_reference = get_tree().get_first_node_in_group(player_group)

func _get_group_reference() -> void:
	_group_reference = get_tree().get_first_node_in_group(custom_group)

func _check_arrival() -> void:
	if is_instance_valid(component_parent):
		var dist := component_parent.global_position.distance_to(target_position)
		has_arrived = dist <= arrival_distance
	else:
		has_arrived = false

func _apply_fallback_position() -> void:
	if is_instance_valid(component_parent):
		target_position = component_parent.global_position
