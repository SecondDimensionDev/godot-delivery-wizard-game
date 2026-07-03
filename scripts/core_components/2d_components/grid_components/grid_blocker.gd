@tool
@icon("uid://cj68nmpfqi6a0")
class_name GridBlocker
extends Node2D

## Component that registers itself as a solid obstacle on the GridMapManager
##
## A component that can be added to any node to ensure it blocks pathfinding on the grid.[br]
## [br]
## [b]Usage:[/b][br]
## Place this node where you want an obstacle.[br]
## The red rectangle shows the blocked area in the editor.
## Ensure you set is_moving_object to true if you want the grid blocker to update every frame [br]
## CRITICAL When using pathfinding this component will block itself! You need to unblock and reblock
## when starting and ending a turn

# CONFIGURATION

@export var block_on_ready: bool = true ## Block the grid immediately
@export var is_moving_object: bool = false ## Does this object move dynamically

@export_group("Shape Definition")
@export var grid_shape: GridShape ## Optional: Reference to a GridShape component.

@export_group("Fallback Settings")
@export var blocked_area_size: Vector2i = Vector2i(1, 1): ## How many tiles this object covers (e.g., 2x2).
	set(value):
		blocked_area_size = value
		queue_redraw()

@export var debug_tile_size: Vector2i = Vector2i(32, 32): ## Visual only: Helps align the rect in the editor to match your grid size
	set(value):
		debug_tile_size = value
		queue_redraw()

@export var debug_color: Color = Color(1, 0, 0, 0.5): ##Visual Only: Define the colour of the debug rectangle drawn in the editor
	set(value):
		debug_color = value
		queue_redraw()

# INTERNAL VARIABLES

var _map_manager: GridMapManager
var _last_blocked_origin: Vector2

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	# If we are in the editor, we don't run game logic, just visuals
	if Engine.is_editor_hint():
		return

	# Locate Manager via Group
	var managers = get_tree().get_nodes_in_group("grid_map_manager")
	if managers.size() > 0:
		_map_manager = managers[0]
	
	if block_on_ready:
		block_tiles()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		unblock_tiles()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if is_moving_object and _map_manager:
		var current_pos = global_position
		var new_tile_origin = _map_manager.get_closest_tile_position(current_pos)
		
		if _last_blocked_origin != new_tile_origin:
			unblock_tiles()
			block_tiles()


# PUBLIC METHODS

func block_tiles() -> void: ## Block the area on the grid.
	if not _map_manager: return
	
	if grid_shape:
		_last_blocked_origin = _map_manager.get_closest_tile_position(grid_shape.global_position)
	else:
		_last_blocked_origin = _map_manager.get_closest_tile_position(global_position)
		
	var cells_to_block: Array[Vector2i] = []
	var origin_cell: Vector2i = _map_manager.base_tile_map.local_to_map(_last_blocked_origin)
	
	if grid_shape:
		cells_to_block = grid_shape.get_occupied_cells(origin_cell)
	else:
		for x in range(blocked_area_size.x):
			for y in range(blocked_area_size.y):
				cells_to_block.append(origin_cell + Vector2i(x, y))
	
	for cell in cells_to_block:
		var target_world = _map_manager.base_tile_map.map_to_local(cell)
		_map_manager.register_dynamic_blocker(target_world)


func unblock_tiles() -> void: ## Unblock the area on the grid.
	if not _map_manager or _last_blocked_origin == Vector2.ZERO: return
	
	var origin_cell = _map_manager.base_tile_map.local_to_map(_last_blocked_origin)
	var cells_to_unblock: Array[Vector2i] = []
	
	if grid_shape:
		cells_to_unblock = grid_shape.get_occupied_cells(origin_cell)
	else:
		for x in range(blocked_area_size.x):
			for y in range(blocked_area_size.y):
				cells_to_unblock.append(origin_cell + Vector2i(x, y))
	
	for cell in cells_to_unblock:
		var target_world = _map_manager.base_tile_map.map_to_local(cell)
		_map_manager.unregister_dynamic_blocker(target_world)
	
	_last_blocked_origin = Vector2.ZERO


# PRIVATE METHODS

func _draw() -> void:
	# Only draw the fallback rect if we don't have a specific shape handling it
	if Engine.is_editor_hint() and not grid_shape:
		var rect_size = Vector2(blocked_area_size) * Vector2(32, 32) # defaulting to 32 for fallback
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(1, 0, 0, 0.5), true)
