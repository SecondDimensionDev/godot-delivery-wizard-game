@icon("uid://l5hg8adak5bg")
class_name GridCamera2D
extends Camera2D

#ENUMS
enum CameraMode {FIXED, MOVABLE, FOLLOWING, AUTO_MOVE, HIT_MARKERS}
enum InterruptMode {LOCKED, UNLOCKED, APPEND_ONLY}

# CONSTANTS
const DISTANCE_THRESHOLD: float = 2.0

# EXPORTED VARIABLES
@export_group("Controls")
@export var manual_drag_enabled: bool = true ## If true, the user can drag-pan the camera.
@export var manual_drag_button: MouseButton = MOUSE_BUTTON_RIGHT ## The mouse button used to initiate the drag.
@export var manual_zoom_enabled: bool = true ## If true, the user can zoomt the camera with the mouse wheel
@export var manual_zoom_in_button: MouseButton = MOUSE_BUTTON_WHEEL_DOWN ## The mouse button used to zoom in.
@export var manual_zoom_out_button: MouseButton = MOUSE_BUTTON_WHEEL_UP ## The mouse button used to zoom out.

@export_group("Zoom Settings")
@export var default_zoom_level: float = 1.0 ## The default zoom level if we need to return to it
@export var min_zoom_out_level: float = 0.75 ## The furthest out you can zoom (smaller number = wider view).
@export var max_zoom_in_level: float = 1.5 ## The closest in you can zoom.
@export var zoom_level_change: float = 0.05 ## How much the zoom changes per scroll tick.
@export var zoom_smoothing_speed: float = 10.0 ## How smoothly the camera lerps to the target zoom
@export var start_at_default_zoom: bool = true ## Should the camera start at the default zoom level, if false camera zoom will start at 1.0
@export var zoom_to_cursor: bool = true ## If true, zooming zooms towards the mouse position rather than screen center.

@export_group("Automated Movement")
@export var auto_move_speed: float = 500.0 ## Max speed for smooth movement.
@export var auto_move_acceleration: float = 600.0 ## Acceleration for smooth movement.
@export var auto_move_deceleration: float = 800.0 ## Deceleration for smooth movement.
@export var follow_speed: float = 5.0 ## Lerp speed for following a target node.

@export_group("Automated Camera Bounds")
@export var grid_map_manager: GridMapManager ## Optional link to the main GridMapManager
@export var use_grid_manager_bounds: bool ## Whether to get the camera bounds from the GridMapManager

@export_group("Camera Sway")
@export var sway_enabled: bool = false ## Should camera sway
@export var sway_noise_speed: float = 10.0 ## How fast the noise scrolls (speed of sway).
@export var sway_noise_strength: float = 0.0 ## How far it moves (pixels). Set 0 to disable default sway.


# PRIVATE VARIABLES
var _camera_mode: CameraMode = CameraMode.FIXED
var _interrupt_mode: InterruptMode = InterruptMode.UNLOCKED

# State Flags
var _is_dragging: bool = false
var _block_dragging: bool = false

# Shake & Sway
var _current_shake_strength: float = 0.0
var _shake_decay: float = 0.0
var _rng := RandomNumberGenerator.new()
var _noise: FastNoiseLite
var _noise_time: float = 0.0

# Automated Movement State
var _auto_path: Array[Vector2] = []
var _current_auto_speed: float = 0.0
var _follow_target: Node2D = null
var _marker_tween: Tween
var _target_zoom: float = 1.0


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	add_to_group("grid_camera_2d")
	
	if grid_map_manager and use_grid_manager_bounds:
		set_world_bounds(grid_map_manager.get_world_bounds())
	
	if manual_drag_enabled:
		_camera_mode = CameraMode.MOVABLE
	
	if start_at_default_zoom:
		_target_zoom = default_zoom_level
	else:
		_target_zoom = zoom.x
	
	# Initialize Noise for Sway
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.2 # Adjust for "smoothness" of the sway
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


func _process(delta: float) -> void:
	# 1. State Management
	if _camera_mode == CameraMode.MOVABLE and not manual_drag_enabled:
		_camera_mode = CameraMode.FIXED
	
	_process_zoom(delta)
	
	# 2. Automated Movement Logic
	match _camera_mode:
		CameraMode.AUTO_MOVE:
			_process_auto_move(delta)
		CameraMode.FOLLOWING:
			_process_follow_target(delta)
	
	
	# 3. Offset Calculation (Sway + Shake)
	var total_offset = Vector2.ZERO
	
	# Sway
	if sway_enabled and sway_noise_strength > 0:
		_noise_time += delta * sway_noise_speed
		var sway_x = _noise.get_noise_2d(_noise_time, 0.0) * sway_noise_strength
		var sway_y = _noise.get_noise_2d(_noise_time, 100.0) * sway_noise_strength
		total_offset += Vector2(sway_x, sway_y)
	
	# Shake
	if _current_shake_strength > 0:
		_current_shake_strength = move_toward(_current_shake_strength, 0.0, _shake_decay * delta)
		total_offset += _get_random_offset()
	
	if total_offset != Vector2.ZERO or offset != Vector2.ZERO:
		offset = total_offset


func _unhandled_input(event: InputEvent) -> void:
	# Handle Zooming
	if manual_zoom_enabled and event is InputEventMouseButton:
		if event.is_pressed():
			if not _is_dragging:
				if event.button_index == manual_zoom_out_button:
					_target_zoom += zoom_level_change
				elif event.button_index == manual_zoom_in_button:
					_target_zoom -= zoom_level_change
				_target_zoom = clampf(_target_zoom, min_zoom_out_level, max_zoom_in_level)
		
	# Handle Dragging
	if _camera_mode != CameraMode.MOVABLE:
		return
	
	if not manual_drag_enabled or _block_dragging:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == manual_drag_button:
			# Toggle drag state based on press/release
			if event.pressed:
				_is_dragging = true
				_reset_zoom_smoothing()
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion:
		if _is_dragging:
			# Move camera opposite to mouse movement
			global_position -= event.relative / zoom
			
			# Clamp immediately to prevent "drift" outside the map
			_clamp_to_bounds()


# PUBLIC METHODS

func set_drag_enabled(is_drag_enabled: bool) -> void: ## Enables drag-panning of the camera using the specfied mouse button
	manual_drag_enabled = is_drag_enabled
	if not manual_drag_enabled:
		_is_dragging = false


func set_world_bounds(bounds: Rect2) -> void: ## Sets the camera limits to the specified rectangle.
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func apply_shake(intensity: float, duration: float = 0.5) -> void: ## Applies a screen shake with a specific intensity (pixel offset) and duration in seconds.
	_current_shake_strength = intensity
	# Calculate how much strength to lose per second to reach 0 by the end of duration
	_shake_decay = intensity / duration if duration > 0 else 0.0


func set_sway(strength: float, speed: float = 10.0, enable_sway: bool = true) -> void: ## Enables or updates the continuous camera sway. Set strength to 0 to stop
	sway_noise_strength = strength
	sway_noise_speed = speed
	sway_enabled = enable_sway


func stop_sway() -> void: ## Stops all camera sway movement
	set_sway(0,0,false)


func zoom_instant(level: float) -> void: ## Instantly sets zoom to a specific level.
	var mouse_world_pos_before = get_global_mouse_position()
	_target_zoom = clampf(level, min_zoom_out_level, max_zoom_in_level)
	zoom = Vector2(_target_zoom, _target_zoom)
	
	if zoom_to_cursor:
		# We calculate where the mouse would be NOW after the zoom changed
		_clamp_to_bounds()
		var mouse_world_pos_after = get_global_mouse_position()
		
		# We calculate the drift caused by the zoom
		var diff = mouse_world_pos_before - mouse_world_pos_after
		
		# We nudge the camera to cancel out the drift
		global_position += diff
		reset_smoothing()
	_clamp_to_bounds()
	reset_smoothing()


func zoom_smooth(level: float) -> void: ## Sets target zoom to a specific level and lerps to target zoom.
	_target_zoom = clampf(level, min_zoom_out_level, max_zoom_in_level)


func zoom_over_duration(level: float, duration: float = 0.5) -> void: ## Smoothly tweens to a zoom level.
	level = clampf(level, min_zoom_out_level, max_zoom_in_level)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "_target_zoom", level, duration)


func request_instant_move(location: Vector2) -> void: ## Instantly moves the camera to a specified position
	var current_position_smooth: bool = position_smoothing_enabled
	position_smoothing_enabled = false
	global_position = location
	call_deferred("_reset_position_smoothing", current_position_smooth)


func request_smooth_move(path: Array[Vector2], interrupt_behavior: InterruptMode = InterruptMode.UNLOCKED, append_path: bool = false) -> void: ## Smoothly moves the camera along a path.
	if not _can_interrupt(append_path):
		return

	var processed_path = _filter_and_clamp_path(path)
	if processed_path.is_empty():
		return

	_set_interrupt_mode(interrupt_behavior)
	_block_dragging = true
	
	if append_path and _camera_mode == CameraMode.AUTO_MOVE:
		# Filter connection to ensure smoothness
		if not _auto_path.is_empty():
			if _auto_path.back().distance_to(processed_path[0]) < DISTANCE_THRESHOLD:
				processed_path.pop_front()
		_auto_path.append_array(processed_path)
	else:
		_camera_mode = CameraMode.AUTO_MOVE
		_auto_path = processed_path
		_current_auto_speed = 0.0 # Reset speed for new path


func request_follow_target(target: Node2D, interrupt_behavior: InterruptMode = InterruptMode.UNLOCKED) -> void: ## Smoothly follows a target node.
	if not _can_interrupt(false):
		return
	
	if not target:
		push_error("GridCamera2D: Cannot follow null target.")
		return

	_set_interrupt_mode(interrupt_behavior)
	_block_dragging = true
	_camera_mode = CameraMode.FOLLOWING
	_follow_target = target


func request_unfollow_target() -> void:
	_reset_camera_state()


func stop_all_camera_movement() -> void:
	_reset_camera_state()


func request_camera_markers(markers: Array, interrupt_behavior: InterruptMode = InterruptMode.UNLOCKED, append: bool = false) -> void: ## Moves between specific points (markers).
	## Markers should be an Array of Dictionaries:
	## { "pos": Vector2, "zoom": float (optional), "pause": float (optional), "speed": float (optional) }
	
	if not _can_interrupt(append):
		return
	
	if markers.is_empty():
		return
	
	_set_interrupt_mode(interrupt_behavior)
	_block_dragging = true
	_camera_mode = CameraMode.HIT_MARKERS

	# If overwriting or starting fresh, kill existing tween
	if not append or not _marker_tween or not _marker_tween.is_valid():
		if _marker_tween: _marker_tween.kill()
		_marker_tween = create_tween()
	
	# Process markers into the Tween
	for marker_data in markers:
		if not marker_data is Dictionary: continue
		
		var target_pos: Vector2 = marker_data.get("pos", global_position)
		var target_zoom: float = marker_data.get("zoom", zoom.x)
		var pause_time: float = marker_data.get("pause", 0.0)
		var move_duration: float = marker_data.get("duration", 1.0)
		
		# Validate Bounds
		target_pos = _get_clamped_position(target_pos, target_zoom)
		target_zoom = clampf(target_zoom, min_zoom_out_level, max_zoom_in_level)
		
		# Add Tween Steps
		# 1. Move & Zoom
		_marker_tween.tween_property(self, "global_position", target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_marker_tween.parallel().tween_property(self, "zoom", Vector2(target_zoom, target_zoom), move_duration)
		
		# 2. Pause (if requested)
		if pause_time > 0.0:
			_marker_tween.tween_interval(pause_time)
	
	# Cleanup callback
	_marker_tween.tween_callback(_on_markers_finished)


# PRIVATE FUNCTIONS

func _can_interrupt(is_append: bool) -> bool:
	if _interrupt_mode == InterruptMode.LOCKED:
		return false
	
	if _interrupt_mode == InterruptMode.APPEND_ONLY:
		if not is_append:
			return false
			
	return true


func _set_interrupt_mode(mode: InterruptMode) -> void:
	_interrupt_mode = mode


func _reset_camera_state() -> void:
	_camera_mode = CameraMode.MOVABLE if manual_drag_enabled else CameraMode.FIXED
	_interrupt_mode = InterruptMode.UNLOCKED
	_block_dragging = false
	_auto_path.clear()
	_follow_target = null


func _on_markers_finished() -> void:
	_reset_camera_state()


func _filter_and_clamp_path(raw_path: Array[Vector2]) -> Array[Vector2]:
	var clean_path: Array[Vector2] = []
	var last_added: Vector2 = Vector2.INF
	
	for point in raw_path:
		var clamped = _get_clamped_position(point, zoom.x)
		
		# Optimization: Skip duplicates caused by clamping
		if clamped.distance_to(last_added) > 1.0:
			clean_path.append(clamped)
			last_added = clamped
			
	return clean_path


func _get_clamped_position(target_pos: Vector2, target_zoom: float) -> Vector2:
	# Calculates where a point would be clamped to, without moving the camera
	var view_size := get_viewport_rect().size / Vector2(target_zoom, target_zoom)
	var half_view := view_size / 2.0
	var min_x := limit_left + half_view.x
	var max_x := limit_right - half_view.x
	var min_y := limit_top + half_view.y
	var max_y := limit_bottom - half_view.y
	
	var res = target_pos
	
	if min_x > max_x:
		res.x = limit_left + (limit_right - limit_left) / 2.0
	else:
		res.x = clampf(res.x, min_x, max_x)
		
	if min_y > max_y:
		res.y = limit_top + (limit_bottom - limit_top) / 2.0
	else:
		res.y = clampf(res.y, min_y, max_y)
		
	return res


func _clamp_to_bounds(_idx: int = 0) -> void:
	# Calculate the viewport size in world units
	var view_size := get_viewport_rect().size / zoom
	var half_view := view_size / 2.0
	
	# Calculate available movement range
	var min_x := limit_left + half_view.x
	var max_x := limit_right - half_view.x
	var min_y := limit_top + half_view.y
	var max_y := limit_bottom - half_view.y
	
	# If the level is smaller than the screen, center the camera
	if min_x > max_x:
		global_position.x = limit_left + (limit_right - limit_left) / 2.0
	else:
		global_position.x = clampf(global_position.x, min_x, max_x)
		
	if min_y > max_y:
		global_position.y = limit_top + (limit_bottom - limit_top) / 2.0
	else:
		global_position.y = clampf(global_position.y, min_y, max_y)


func _get_random_offset() -> Vector2:
	return Vector2(
		_rng.randf_range(-_current_shake_strength, _current_shake_strength),
		_rng.randf_range(-_current_shake_strength, _current_shake_strength)
	)


func _process_auto_move(delta: float) -> void:
	if _auto_path.is_empty():
		_reset_camera_state()
		return

	var target: Vector2 = _auto_path[0]
	var dist_to_target: float = global_position.distance_to(target)
	var target_speed: float = auto_move_speed
	
	# 1. Braking Logic (Look Ahead)
	if auto_move_deceleration > 0:
		var stop_dist = (_current_auto_speed * _current_auto_speed) / (2 * auto_move_deceleration)
		var remaining_path_dist = dist_to_target
		
		# Look ahead up to 5 nodes to see if we need to stop soon
		for i in range(_auto_path.size() - 1):
			if remaining_path_dist > stop_dist: break
			remaining_path_dist += _auto_path[i].distance_to(_auto_path[i+1])
			
		if remaining_path_dist <= stop_dist:
			target_speed = 0.0

	# 2. Acceleration
	if auto_move_acceleration > 0:
		_current_auto_speed = move_toward(_current_auto_speed, target_speed, auto_move_acceleration * delta)
	else:
		_current_auto_speed = auto_move_speed
		
	# 3. Move
	var move_dist = _current_auto_speed * delta
	
	while move_dist > 0 and not _auto_path.is_empty():
		target = _auto_path[0]
		dist_to_target = global_position.distance_to(target)
		
		if dist_to_target <= move_dist:
			move_dist -= dist_to_target
			global_position = target
			_auto_path.pop_front()
			if _auto_path.is_empty():
				_reset_camera_state()
				return
		else:
			global_position = global_position.move_toward(target, move_dist)
			move_dist = 0


func _process_follow_target(delta: float) -> void:
	if not is_instance_valid(_follow_target):
		_reset_camera_state()
		return
		
	# Get desired position (clamped)
	var target_pos = _get_clamped_position(_follow_target.global_position, zoom.x)
	
	# Smoothly interpolate
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# Snap if very close to prevent jitter
	if global_position.distance_squared_to(target_pos) < 1.0:
		global_position = target_pos


func _process_zoom(delta: float) -> void:
	# Optimization: Don't run math if we are already at the target
	if is_equal_approx(zoom.x, _target_zoom):
		return
	
	# 1. ANCHOR POINT (Fixes Point 3 "Zoom to Cursor")
	# We grab the position in the world currently under the mouse.
	var mouse_world_pos_before = get_global_mouse_position()
	
	# 2. LERP ZOOM (Fixes Point 1 "Jerky Zoom")
	var new_zoom_val = lerp(zoom.x, _target_zoom, zoom_smoothing_speed * delta)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	
	# 3. APPLY POSITION CORRECTION
	if zoom_to_cursor:
		# We calculate where the mouse would be NOW after the zoom changed
		_clamp_to_bounds()
		var mouse_world_pos_after = get_global_mouse_position()
		
		# We calculate the drift caused by the zoom
		var diff = mouse_world_pos_before - mouse_world_pos_after
		
		# We nudge the camera to cancel out the drift
		global_position += diff
		reset_smoothing()
		_clamp_to_bounds()
		reset_smoothing()
	else:
		_clamp_to_bounds()
		reset_smoothing()


func _reset_zoom_smoothing() -> void:
	_target_zoom = zoom.x


func _reset_position_smoothing(smoothing: bool) -> void:
	position_smoothing_enabled = smoothing
