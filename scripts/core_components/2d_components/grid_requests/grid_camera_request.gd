@icon("uid://dvg0l7pjfjsh")
class_name GridCameraRequest
extends Node

## Handles camera focus requests between a parent entity and the GridCamera2D.
##
## This component acts as a bridge between an entity (inheriting from [Node2D]) and the global
## [GridCamera2D]. It locates the camera via the 'grid_camera_2d' group, allowing
## isolated objects (like triggers or units) to control camera focus without
## hard dependencies.[br]
## Camera priority from 1 to 10 can be sent as an optional argument, lower prioity movement
## calls will be ignored if higher priority movement calls are still active.[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add as a child node of any entity (Player, Cutscene Trigger, etc).[br]
## 2. Call request_focus_* methods to move the camera or request_screen* for shake and sway

# SIGNALS
signal request_failed(reason: String) ## Emitted if the camera cannot be found.

# ENUMS
## Determines how the camera handles this request if it is already doing something else.
enum InterruptMode { 
	LOCKED, ## Cannot interrupt the current action. Request will be ignored.
	UNLOCKED, ## Immediately replaces the current action.
	APPEND_ONLY ## Only accepted if it can be appended to the current queue.
}

# INTERNAL VARIABLES

@export var _parent_node: Node2D
var _camera: GridCamera2D ## Reference to the global grid camera.

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	_locate_camera()


# PUBLIC METHODS

func request_focus_instant(target_pos: Vector2) -> void: ## Teleports camera instantly.
	if _validate_camera():
		_camera.request_instant_move(target_pos)


func request_focus_smooth(target_pos: Vector2, interrupt_mode: InterruptMode = InterruptMode.UNLOCKED) -> void: ## Smoothly moves to a single point.
	if _validate_camera():
		# We wrap the single point in an array for the generic handler
		_camera.request_smooth_move([target_pos], _convert_interrupt_mode(interrupt_mode), false)


func request_path_move(path_points: Array[Vector2], interrupt_mode: InterruptMode = InterruptMode.UNLOCKED, append: bool = false) -> void: ## Moves along a path of points.
	if _validate_camera():
		_camera.request_smooth_move(path_points, _convert_interrupt_mode(interrupt_mode), append)


func request_follow_self(interrupt_mode: InterruptMode = InterruptMode.UNLOCKED) -> void: ## Locks camera to parent node.
	if not _parent_node:
		push_warning("GridCameraRequest: Parent is not a Node2D, cannot focus on self.")
		return
		
	if _validate_camera():
		_camera.request_follow_target(_parent_node, _convert_interrupt_mode(interrupt_mode))


func request_follow_target(target: Node2D, interrupt_mode: InterruptMode = InterruptMode.UNLOCKED) -> void: ## Locks camera to specific target.
	if _validate_camera():
		_camera.request_follow_target(target, _convert_interrupt_mode(interrupt_mode))


func request_unfollow() -> void: ## Stops following a target
	if _validate_camera():
		_camera.request_unfollow_target()


func request_camera_stop() -> void: ## Stops all camera movements
	if _validate_camera():
		_camera.stop_all_camera_movement()


func request_marker_sequence(markers: Array, interrupt_mode: InterruptMode = InterruptMode.UNLOCKED, append: bool = false) -> void: ## Plays a marker sequence.
	## Markers must be an Array of Dictionaries: { "pos": Vector2, "zoom": float, "duration": float, "pause": float }
	if _validate_camera():
		_camera.request_camera_markers(markers, _convert_interrupt_mode(interrupt_mode), append)


func request_zoom_instant(level: float) -> void: ## Changes zoom level instantly
	if _validate_camera():
		_camera.zoom_instant(level)


func request_zoom_smooth(level: float) -> void: ## Changes zoom level smoothly
	if _validate_camera():
		_camera.zoom_smooth(level)


func request_zoom_over_time(level: float, duration: float = 0.0) -> void: ## Changes zoom level over time. 0 duration = instant.
	if _validate_camera():
		if duration <= 0:
			_camera.zoom_smooth(level)
		else:
			_camera.zoom_over_duration(level, duration)


func request_screen_shake(intensity: float, duration: float = 0.5) -> void: ## Requests a screen shake.
	if _validate_camera():
		_camera.apply_shake(intensity, duration)


func request_screen_sway(strength: float, speed: float = 10.0, enable_sway: bool = true) -> void: ## Sets continuous camera sway. Set 0 strength to stop
	if _validate_camera():
		_camera.set_sway(strength, speed, enable_sway)


func request_sway_stop() -> void: ## Request all camera sway effects are stopped
	if _validate_camera():
		_camera.stop_sway()


# PRIVATE FUNCTIONS

func _locate_camera() -> void:
	var cameras := get_tree().get_nodes_in_group("grid_camera_2d")
	
	if cameras.size() > 0:
		_camera = cameras[0] as GridCamera2D
	
	if cameras.size() > 1:
		push_warning("Multiple GridCamera2D nodes found. Using the first one.")


func _validate_camera() -> bool:
	if not _camera:
		# Attempt to find it one last time (in case it was added late)
		_locate_camera()
		
	if not _camera:
		request_failed.emit("No GridCamera2D found in group 'grid_camera'")
		return false
		
	return true


func _convert_interrupt_mode(local_mode: InterruptMode) -> GridCamera2D.InterruptMode:
	# Maps the local enum to the Camera class enum to avoid type errors
	match local_mode:
		InterruptMode.LOCKED: return GridCamera2D.InterruptMode.LOCKED
		InterruptMode.UNLOCKED: return GridCamera2D.InterruptMode.UNLOCKED
		InterruptMode.APPEND_ONLY: return GridCamera2D.InterruptMode.APPEND_ONLY
		_: return GridCamera2D.InterruptMode.UNLOCKED
