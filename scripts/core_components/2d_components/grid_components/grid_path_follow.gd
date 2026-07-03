@icon("uid://ou444t1kcgaw")
class_name GridPathFollow
extends Node
## Component for grid-based movement logic.
##
## This component handles movement logic for a parent Node2D along a path of Vector2 coordinates.
## It supports both continuous movement with physics-like acceleration/deceleration and
## stepped grid-based movement using Tweens.[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add a child Node to the Node2D you wish to move.[br]
## 2. Attach this script to the new node.[br]
## 3. Assign the parent node in the "Setup" export variable.[br]
## 4. Call [method move_along_path] with an Array of Vector2 coordinates to begin movement.[br]
## 5. Listen to signals [signal waypoint_reached] or [signal path_finished] for game logic.


# SIGNALS
signal path_started ## Emitted when movement begins.
signal waypoint_reached(last_index) ## Emitted when a specific point in the path is reached.
signal path_finished ## Emitted when the end of the path is reached.


# ENUMS
enum MovementStyle { CONTINUOUS, STEPPED } ## Defines the type of movement logic used.


# EXPORTED VARIABLES
@export_group("Setup")
@export var _parent_node: Node2D ## The node to be moved.

@export_group("Settings")
@export var max_speed: float = 200.0 ## Top speed in pixels per second.
@export var arrive_threshold: float = 2.0 ## Distance to target to consider "arrived".

@export_group("Continuous Physics")
@export var acceleration: float = 400.0 ## Acceleration in px/s^2. 0 is instant.
@export var deceleration: float = 800.0 ## Deceleration in px/s^2. 0 is instant.

@export_group("Rotation")
@export var rotate_to_path: bool = false ## If true, parent rotates to face movement direction.
@export var smooth_rotation: bool = true ## Enables smooth turning instead of instant snapping.
@export var rotation_speed: float = 10.0 ## Speed of rotation (higher is faster).

@export_group("Movement Style")
@export var movement_style: MovementStyle = MovementStyle.CONTINUOUS ## Toggle between physics or tween-based movement.
@export var step_curve: Tween.TransitionType = Tween.TRANS_SINE ## Tween transition for stepped movement.
@export var step_ease: Tween.EaseType = Tween.EASE_IN_OUT ## Tween easing for stepped movement.


# PRIVATE VARIABLES
var _path_queue: Array[Vector2] = []
var _is_moving: bool = false
var _current_speed: float = 0.0


# VIRTUAL FUNCTIONS
func _ready() -> void:
	if not _parent_node:
		push_error("No Parent Node Assigned")
		set_process(false)


func _process(delta: float) -> void:
	if not _is_moving or movement_style == MovementStyle.STEPPED:
		return
	
	_process_continuous_movement(delta)


# PUBLIC FUNCTIONS

func move_along_path(points: Array[Vector2]) -> void: ## Starts or updates movement along the provided path points.
	if points.is_empty():
		return

	# If we are stopped, perform a fresh start (Hard Reset)
	if not _is_moving:
		_start_new_path(points)
		return

	# If we ARE moving, perform a Seamless Update (Momentum Preservation)
	_path_queue = points.duplicate()
	
	# Handle "Start Node" Jitter
	# If the new path starts at the tile we are currently standing on (or very close to),
	# we skip it to prevent the unit from stuttering backward before moving forward.
	if _path_queue.size() > 0:
		var dist_to_start = _parent_node.global_position.distance_to(_path_queue[0])
		if dist_to_start < 5.0: 
			_path_queue.pop_front()


func append_path(new_points: Array[Vector2]) -> void: ## Adds points to the end of the current path without stopping.
	if new_points.is_empty():
		return

	# If we aren't moving, this is just a normal move command
	if not _is_moving:
		move_along_path(new_points)
		return

	# FILTERING: Connect the two paths smoothly
	# If the new path starts exactly where the current path ends, 
	# remove that duplicate point so we flow through it without stopping.
	if not _path_queue.is_empty():
		var end_of_current = _path_queue.back()
		var start_of_new = new_points[0]
		
		# If they are practically the same point (e.g. within 1 pixel)
		if end_of_current.distance_to(start_of_new) < 1.0:
			new_points.pop_front()

	# Add the new points to the end of the queue
	_path_queue.append_array(new_points)


func stop_movement(emergency_stop: bool = false) -> void: ## Stops movement after the current waypoint is reached, or immediately on emergency stop
	if emergency_stop:
		_stop_movement_now()
	else:
		_stop_movement_safely()


func get_remaining_path() -> Array[Vector2]: ## Returns the list of points still waiting to be visited.
	return _path_queue


func get_final_destination() -> Vector2: ## Returns the final point in the current path.
	if not _path_queue.is_empty():
		return _path_queue.back()
	
	# If no path exists, our "destination" is simply where we are right now.
	if _parent_node:
		return _parent_node.global_position
		
	return Vector2.ZERO


# PRIVATE FUNCTIONS

func _start_new_path(points: Array[Vector2]) -> void: # Starts movement along the provided path points.
	if points.is_empty():
		return
	
	_path_queue = points.duplicate()
	_is_moving = true
	_current_speed = 0.0
	emit_signal("path_started")
	
	if movement_style == MovementStyle.STEPPED:
		_start_next_step_tween()


func _process_continuous_movement(delta: float) -> void:
	if _path_queue.is_empty():
		_finish_path()
		return

	# --- 1. BRAKING LOGIC (Looking Ahead) ---
	var target: Vector2 = _path_queue[0]
	var current_pos: Vector2 = _parent_node.global_position
	var dist_to_target: float = current_pos.distance_to(target)
	
	var target_speed: float = max_speed
	
	if deceleration > 0:
		var required_stop_dist: float = (_current_speed * _current_speed) / (2 * deceleration)
		var total_dist_remaining: float = dist_to_target
		
		# Look ahead loop
		for i in range(_path_queue.size() - 1):
			if total_dist_remaining > required_stop_dist:
				break
			total_dist_remaining += _path_queue[i].distance_to(_path_queue[i+1])

		if total_dist_remaining <= required_stop_dist:
			target_speed = 0.0

	# --- 2. APPLY ACCELERATION ---
	if acceleration > 0:
		_current_speed = move_toward(_current_speed, target_speed, acceleration * delta)
	else:
		_current_speed = max_speed

	# --- 3. MOVEMENT WITH OVERSHOOT (Item #2) ---
	var move_distance_remaining = _current_speed * delta

	# Loop allows us to pass multiple points in a single frame if they are close together
	while (move_distance_remaining > 0 or current_pos.distance_to(target) < 0.001) and not _path_queue.is_empty():
		target = _path_queue[0]
		dist_to_target = current_pos.distance_to(target)

		if dist_to_target <= move_distance_remaining:
			# We reach the waypoint and have distance left over
			move_distance_remaining -= dist_to_target
			current_pos = target # Teleport logically to the node
			_parent_node.global_position = current_pos
			
			_path_queue.pop_front()
			waypoint_reached.emit(_path_queue.size())
			
			if _path_queue.is_empty():
				_finish_path() 
				return
		else:
			# We cannot reach the next point, just move towards it
			current_pos = current_pos.move_toward(target, move_distance_remaining)
			_parent_node.global_position = current_pos
			move_distance_remaining = 0 # Movement for this frame is consumed

	# --- 4. SMOOTH ROTATION (Item #3) ---
	if rotate_to_path and not _path_queue.is_empty():
		# Look at the target we are currently moving towards
		target = _path_queue[0]
		var angle_to_target = (target - _parent_node.global_position).angle()
		
		if smooth_rotation:
			_parent_node.rotation = lerp_angle(_parent_node.rotation, angle_to_target, rotation_speed * delta)
		else:
			_parent_node.rotation = angle_to_target


func _start_next_step_tween() -> void:
	if _path_queue.is_empty():
		_finish_path()
		return
		
	var target = _path_queue.pop_front()
	var current_pos = _parent_node.global_position
	var distance = current_pos.distance_to(target)
	
	var duration = distance / max_speed
	
	var tween = get_tree().create_tween()
	tween.set_trans(step_curve)
	tween.set_ease(step_ease)
	
	if rotate_to_path:
		_parent_node.look_at(target)
	
	tween.tween_property(_parent_node, "global_position", target, duration)
	tween.tween_callback(func(): 
		emit_signal("waypoint_reached", _path_queue.size())
		_start_next_step_tween()
	)


func _finish_path() -> void:
	_is_moving = false
	_current_speed = 0.0
	emit_signal("path_finished")


func _stop_movement_safely() -> void: # Stops movement after the current waypoint is reached.
	if _path_queue.is_empty():
		return

	# In Continuous mode, the first point in the queue IS the current target.
	# We want to reach it, then stop. So we keep index 0 and remove the rest.
	if movement_style == MovementStyle.CONTINUOUS:
		var current_target = _path_queue[0]
		_path_queue.clear()
		_path_queue.append(current_target)
		
	# In Stepped mode, the current target has already been popped off the queue
	# and is currently being tweened. Clearing the queue ensures no new tweens start.
	elif movement_style == MovementStyle.STEPPED:
		_path_queue.clear()


func _stop_movement_now() -> void: # Immediately stops all movement and clears the path.
	_is_moving = false
	_path_queue.clear()
	_current_speed = 0.0
	
	# Stop any active tweens
	var tw = get_tree().create_tween()
	tw.kill()
