@tool
@icon("uid://b08pyy7e330n3")
class_name GridLineOverlay
extends Node2D
## Draws a grid overlay onto the game world.
##
## This script renders a grid based on configured cell size and dimensions.
## It can function independently with manual settings or synchronize automatically
## with a [GridMapManager] to match the game's tile layout.[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add this node to a Node2D in your main scene.[br]
## 2. Option A (Manual): Set 'grid_size' and 'cell_size' in the Inspector.[br]
## 3. Option B (Automatic): Assign the 'grid_manager' export to your active GridMapManager.[br]
## 4. Toggle 'show_grid' to true to enable drawing.

# CONFIGURATION
@export_group("Grid Settings")
@export var grid_size: Vector2i = Vector2i(20, 15) ## Dimensions of the grid in cells.
@export var cell_size: Vector2i = Vector2i(32, 32) ## Pixel size of a single cell.
@export var show_grid: bool = true: ## Toggles grid visibility and triggers redraws.
	set(value):
		show_grid = value
		queue_redraw()
@export_tool_button("Re-Draw", "Edit")
var export_action_draw: Callable = queue_redraw

@export_group("Visuals")
@export var line_color: Color = Color(1, 1, 1, 0.2) ## Color of the grid lines (supports alpha).
@export var line_width: float = 1.0 ## Width of the grid lines in pixels.
@export_tool_button("Re-Draw", "Edit")
var export_action_draw_colour: Callable = queue_redraw

# DEPENDENCIES
@export_group("Grid Manager")
@export var grid_manager: GridMapManager ## Optional manager to sync grid dimensions with.
@export_tool_button("Re-Sync", "Reload")
var export_action_sync: Callable = _sync_with_manager

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	if grid_manager:
		# Wait for manager initialization
		await get_tree().process_frame
		_sync_with_manager()


func _draw() -> void:
	if not show_grid:
		return

	var total_width := grid_size.x * cell_size.x
	var total_height := grid_size.y * cell_size.y

	# Draw Vertical Lines
	for x in range(grid_size.x + 1):
		var x_pos := x * cell_size.x
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, total_height), line_color, line_width)

	# Draw Horizontal Lines
	for y in range(grid_size.y + 1):
		var y_pos := y * cell_size.y
		draw_line(Vector2(0, y_pos), Vector2(total_width, y_pos), line_color, line_width)


# PRIVATE METHODS

func _sync_with_manager() -> void:
	if not grid_manager or not grid_manager.base_tile_map:
		return
		
	# Sync Cell Size
	if grid_manager.override_cell_size == Vector2i.ZERO:
		if grid_manager.base_tile_map:
			cell_size = grid_manager.base_tile_map.tile_set.tile_size
		else:
			push_error("GridMapManager: TileMap has no TileSet assigned!")
			return
	else:
		cell_size = grid_manager.override_cell_size
	
	# Sync Grid Dimensions
	var map_rect := grid_manager.base_tile_map.get_used_rect()
	grid_size = map_rect.size
	
	# Align position to tilemap
	position = grid_manager.base_tile_map.map_to_local(map_rect.position) - (Vector2(cell_size) / 2.0)
	
	queue_redraw()
