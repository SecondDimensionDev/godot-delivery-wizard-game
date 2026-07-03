class_name LinearMapDisplay
extends Control

## Handles the visual generation of the map using strict grid-cell centering.
##
## Defines a grid based on the Control's size and places nodes in the center of 
## their calculated cells.

# ENUMS
enum ConnectionType { STRAIGHT, CURVED }


# EXPORT VARIABLES
@export var map_manager: LinearMapManager
@export var location_scene: PackedScene

@export_group("Variation")
@export var visual_seed: int = 0 ## Seed for visual jitter (independent of logic seed).
@export var grid_jitter_movement: float = 10.0 ## Max pixel offset along the path flow (X in L->R, Y in T->B).
@export var grid_jitter_breadth: float = 30.0 ## Max pixel offset across the lanes (Y in L->R, X in T->B).

@export_group("Player Indicator")
@export var player_indicator: Sprite2D

@export_group("Line Style")
@export var line_texture: Texture2D
@export var line_texture_mode: Line2D.LineTextureMode = Line2D.LINE_TEXTURE_TILE
@export var line_width: float = 4.0
@export var connection_type: ConnectionType = ConnectionType.CURVED
@export_range(0.0, 1.0) var curve_tension: float = 0.5 ## How "loose" the curves are (0 = straight, 1 = wide).

@export_group("Line Colours")
#@export var line_color: Color = Color.WHITE
@export var line_color_default: Color = Color.WHITE
@export var line_color_available: Color = Color.YELLOW ## Highlight path
@export var line_color_skipped: Color = Color(1, 1, 1, 0.1) ## Faint line
@export var line_color_locked: Color = Color(1, 1, 1, 0.1) ## Faint line
@export var line_color_unreachable: Color = Color(1, 1, 1, 0.1) ## Faint line


# PRIVATE VARIABLES
var _location_instances: Dictionary = {} 
var _lines_container: Node2D
var _rng := RandomNumberGenerator.new()

# GRID CALCULATIONS
var _current_col_count: int = 1
var _current_row_count: int = 1

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_lines_container = Node2D.new()
	_lines_container.name = "LinesContainer"
	add_child(_lines_container)
	
	if map_manager:
		map_manager.map_generated.connect(update_map)
		map_manager.map_data_updated.connect(_on_map_data_updated)
		map_manager.player_moved.connect(set_player_postition)
	
	resized.connect(update_map)


# PUBLIC FUNCTIONS
func update_map() -> void: 
	_clear_display()
	
	if not map_manager or map_manager.all_nodes.is_empty():
		return
		
	# Initialize visual RNG
	if visual_seed != 0:
		_rng.seed = visual_seed
	else:
		_rng.randomize()
		
	# 1. Analyze Data to determine grid dimensions
	_recalculate_grid_dimensions()
	
	# 2. Create Location Instances
	for node_id in map_manager.all_nodes:
		var data: LinearMapNodeData = map_manager.all_nodes[node_id]
		_create_location_visual(data)
	
	# 3. Create Line2D connections
	_create_all_connections()
	
	# 4. Update Player Indicator Position
	if map_manager.current_player_node_id != "":
		set_player_postition(map_manager.current_player_node_id)


func set_player_postition(new_player_location: String) -> void:
	if not player_indicator or not map_manager:
		return
	var location: LinearMapLocation = get_location_instance_by_grid_string(new_player_location)
	
	if location:
		if location.player_inicator_location:
			player_indicator.global_position = location.player_inicator_location.global_position


func get_location_instance_by_grid_string(grid_pos: String) -> LinearMapLocation:
	# 1. Reconstruct the ID based on the Manager's naming convention
	var id_lookup = grid_pos
	
	# 2. Return the instance directly (or null if not found)
	# Dictionary.get() returns null if the key doesn't exist, which is safe.
	return _location_instances.get(id_lookup) as LinearMapLocation


func get_location_instance_by_grid_vector(grid_pos: Vector2i) -> LinearMapLocation:
	# 1. Reconstruct the ID based on the Manager's naming convention
	var id_lookup = "%d_%d" % [grid_pos.x, grid_pos.y]
	
	# 2. Return the instance directly (or null if not found)
	# Dictionary.get() returns null if the key doesn't exist, which is safe.
	return _location_instances.get(id_lookup) as LinearMapLocation


#func get_node_position_by_grid_id(grid_pos: Vector2i) -> Vector2:
	## 1. Reconstruct the ID based on the Manager's naming convention (col_row)
	#var id_lookup = "%d_%d" % [grid_pos.x, grid_pos.y]
	#
	## 2. Find the instance in our existing dictionary
	#var instance = _location_instances.get(id_lookup)
	#
	## 3. Return position if found
	#if instance:
		#return instance.position
		#
	## 4. Safety fallback
	#push_warning("LinearMapDisplay: No location found at grid %s" % grid_pos)
	#return Vector2.ZERO


# PRIVATE FUNCTIONS
func _recalculate_grid_dimensions() -> void:
	var max_x_index = 0
	var max_y_index = 0
	
	for node_id in map_manager.all_nodes:
		var node = map_manager.all_nodes[node_id]
		if node.grid_position.x > max_x_index: max_x_index = node.grid_position.x
		if node.grid_position.y > max_y_index: max_y_index = node.grid_position.y
	
	# Column Count is Index + 1 (e.g., Index 0 to 4 = 5 columns)
	_current_col_count = max_x_index + 1
	_current_row_count = max_y_index + 1


func _calculate_position(grid_pos: Vector2i) -> Vector2:
	# 1. Get the size of a single cell based on the Control's full rect
	var cell_width: float
	var cell_height: float
	var target_x: float = 0.0
	var target_y: float = 0.0
	
	# Jitter calculation vars
	var jitter_x: float = 0.0
	var jitter_y: float = 0.0
	
	if map_manager.orientation == LinearMapManager.MapOrientation.LEFT_TO_RIGHT:
		# Orientation: X Axis = Progress (Columns), Y Axis = Lanes (Rows)
		cell_width = size.x / float(max(1, _current_col_count))
		cell_height = size.y / float(max(1, _current_row_count))
		
		# Center in grid
		target_x = (grid_pos.x * cell_width) + (cell_width * 0.5)
		target_y = (grid_pos.y * cell_height) + (cell_height * 0.5)
		
		# Apply directional jitter
		jitter_x = _rng.randf_range(-grid_jitter_movement, grid_jitter_movement)
		jitter_y = _rng.randf_range(-grid_jitter_breadth, grid_jitter_breadth)
		
	else:
		# Orientation: Y Axis = Progress (Columns in data), X Axis = Lanes (Rows in data)
		cell_width = size.x / float(max(1, _current_row_count))
		cell_height = size.y / float(max(1, _current_col_count))
		
		# Center in grid
		target_x = (grid_pos.y * cell_width) + (cell_width * 0.5)
		target_y = (grid_pos.x * cell_height) + (cell_height * 0.5)
		
		# Apply directional jitter (Swapped axes)
		jitter_x = _rng.randf_range(-grid_jitter_breadth, grid_jitter_breadth)
		jitter_y = _rng.randf_range(-grid_jitter_movement, grid_jitter_movement)
	
	return Vector2(target_x + jitter_x, target_y + jitter_y)


func _create_all_connections() -> void:
	if not map_manager: return
	
	for node_id in map_manager.all_nodes:
		var source_data = map_manager.all_nodes[node_id]
		var source_inst = _location_instances.get(node_id)
		if not source_inst: continue
	
		for target_id in source_data.connected_to_ids:
			if target_id in map_manager.all_nodes:
				var target_inst = _location_instances.get(target_id)
				if not target_inst: continue
				_spawn_connection_line(source_inst, target_inst)


func _redraw_lines() -> void:
	# Clear existing lines from the container
	# We use get_children() because we only want to remove the Line2Ds, 
	# not the container itself.
	for child in _lines_container.get_children():
		child.queue_free()
	
	# Re-run the connection logic
	# This will use the CURRENT status of the nodes to determine line colors
	_create_all_connections()


func _spawn_connection_line(source_inst: LinearMapLocation, target_inst: LinearMapLocation) -> void:
	var start_offset = Vector2.ZERO
	var end_offset = Vector2.ZERO
	
	if map_manager.orientation == LinearMapManager.MapOrientation.LEFT_TO_RIGHT:
		start_offset = source_inst.get_port_position("East")
		end_offset = target_inst.get_port_position("West")
	else:
		start_offset = source_inst.get_port_position("South")
		end_offset = target_inst.get_port_position("North")
	
	var start_pos = source_inst.position + start_offset
	var end_pos = target_inst.position + end_offset
	
	var source_status = source_inst.node_data.status
	var target_status = target_inst.node_data.status
	var draw_color = line_color_default
	
	if target_status == LinearMapNodeData.LocationStatus.UNREACHABLE:
		draw_color = line_color_unreachable
	elif source_status == LinearMapNodeData.LocationStatus.SKIPPED:
		draw_color = line_color_skipped
	elif source_status == LinearMapNodeData.LocationStatus.UNREACHABLE:
		draw_color = line_color_unreachable
	else:
		match target_status:
			LinearMapNodeData.LocationStatus.UNREACHABLE:
				draw_color = line_color_unreachable
			LinearMapNodeData.LocationStatus.SKIPPED:
				draw_color = line_color_skipped # Standard visible line
			LinearMapNodeData.LocationStatus.NEXT_LOCKED:
				draw_color = line_color_default # Standard visible line
			LinearMapNodeData.LocationStatus.AVAILABLE:
				draw_color = line_color_available
			LinearMapNodeData.LocationStatus.LOCKED:
				draw_color = line_color_locked
			_:
				draw_color = line_color_default

	var line = Line2D.new()
	line.width = line_width
	line.default_color = draw_color # Apply calculated color
	line.texture = line_texture
	line.texture_mode = line_texture_mode
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	if connection_type == ConnectionType.STRAIGHT:
		line.add_point(start_pos)
		line.add_point(end_pos)
	else:
		_apply_curved_points(line, start_pos, end_pos)
		
	_lines_container.add_child(line)


func _apply_curved_points(line: Line2D, start: Vector2, end: Vector2) -> void:
	var curve = Curve2D.new()
	
	# Determine control points based on orientation and tension
	var diff = end - start
	var control_offset = Vector2.ZERO
	
	if map_manager.orientation == LinearMapManager.MapOrientation.LEFT_TO_RIGHT:
		# For L->R, curve pushes Right from start, Left from end
		var dist_x = abs(diff.x)
		control_offset = Vector2(dist_x * curve_tension, 0)
	else:
		# For T->B, curve pushes Down from start, Up from end
		var dist_y = abs(diff.y)
		control_offset = Vector2(0, dist_y * curve_tension)
	
	# Add points (In/Out vectors are relative to the point)
	# Start point has an OUT vector
	curve.add_point(start, Vector2.ZERO, control_offset)
	# End point has an IN vector (negative offset to point backwards)
	curve.add_point(end, -control_offset, Vector2.ZERO)
	
	line.points = curve.get_baked_points()


func _create_location_visual(data: LinearMapNodeData) -> void:
	if not location_scene:
		push_warning("LinearMapDisplay: No Location Scene assigned.")
		return
		
	var instance = location_scene.instantiate() as LinearMapLocation
	if not instance: return
	
	add_child(instance)
	
	# Calculate position with Jitter
	instance.position = _calculate_position(data.grid_position)
	
	instance.setup(data)
	instance.location_selected.connect(_on_location_selected)
	_location_instances[data.id] = instance


func _clear_display() -> void:
	for child in get_children():
		if child != _lines_container:
			child.queue_free()
	
	for line in _lines_container.get_children():
		line.queue_free()
		
	_location_instances.clear()


func _on_location_selected(data: LinearMapNodeData) -> void:
	if map_manager:
		map_manager.attempt_move_player(data.id)


func _on_map_data_updated() -> void:
	# 1. Update existing Location Instances
	for id in _location_instances:
		var instance = _location_instances[id]
		instance.refresh_status()
	
	# 2. Redraw Lines to reflect new path statuses (e.g. Unreachable vs Available)
	_redraw_lines()
