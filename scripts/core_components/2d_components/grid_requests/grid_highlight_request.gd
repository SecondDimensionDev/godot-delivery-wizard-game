@icon("uid://c7w8ewy0yjel6")
class_name GridHighlightRequest
extends Node

## Helper class to request grid highlighting updates from a central manager.
##
## This script acts as a bridge between game objects (like units, UI, or abilities)
## and the [GridHighlightManager]. It automatically locates the manager within the
## "grid_highlighter" group, decoupling the requester from the specific map implementation.[br]
## [br]
## [b]Usage:[/b][br]
## # 1. Add this node as a child of your object.[br]
## # 2. Call request_highlight() to draw cells.[br]
## [codeblock]
## @onready var highlighter = $GridHighlightRequest
##
## func _on_selected():
##     var cells = [Vector2(0,0), Vector2(0,1)]
##     highlighter.request_highlight("move_range", cells, true)
## [/codeblock]

# DEPENDENCIES
@export var parent: Node2D
@export var grid_shape: GridShape ## Cached reference to the parent's shape

# PRIVATE VARIABLES

var _map_highlighter: GridHighlightManager ## Reference to the active highlight manager found in the scene tree.
var _map_manager: GridMapManager ## Reference to the data/pathfinding manager

# VIRTUAL METHODS

func _ready() -> void:
	# Connect to Grid Highlghter
	var grid_highlighters := get_tree().get_nodes_in_group("grid_highlighter")
	if not grid_highlighters.is_empty():
		_map_highlighter = grid_highlighters[0]
	
	# Connect to Grid Manager
	var map_managers := get_tree().get_nodes_in_group("grid_map_manager")
	if not map_managers.is_empty():
		_map_manager = map_managers[0]


# PUBLIC METHODS

func request_highlight_self(style: String) -> void: ## Highlights the exact footprint of this entity.
	if not _map_highlighter: return
	
	var cells: Array[Vector2i] = []
	var root_cell = Vector2i.ZERO
	
	# Get current grid position
	if _map_manager and parent:
		root_cell = _map_manager.base_tile_map.local_to_map(parent.global_position)
	
	# Get shape cells or fallback to single cell
	if grid_shape:
		cells = grid_shape.get_occupied_cells(root_cell)
	else:
		cells.append(root_cell)

	# The manager expects World Positions for the add_highlights API? 
	# Looking at your GridHighlightManager , it expects World Positions.
	# Let's convert them back to world for the API consistency.
	var world_cells: Array[Vector2] = []
	for cell in cells:
		# Note: You might want to map these to the CENTER of the cell
		if _map_manager:
			world_cells.append(_map_manager.base_tile_map.map_to_local(cell))
			
	_map_highlighter.add_highlights(style, world_cells, true)


func request_highlight(style: String, highlight_positions: Array[Vector2], clear_previous_highlights: bool) -> void: ## Submits a request to paint specific grid cells with a given style.
	if _map_highlighter:
		_map_highlighter.add_highlights(style, highlight_positions, clear_previous_highlights)


func request_clear_highlight(style: String = "") -> void:
	if _map_highlighter:
		_map_highlighter.clear_highlights(style)


func set_tile_cursor(cursor_position: Vector2, cursor_style: String) -> void: ## Updates the position and visual style of the map cursor.
	if _map_highlighter:
		_map_highlighter.set_tile_cursor(cursor_position, cursor_style)


func clear_tile_cursor() -> void:
	if _map_highlighter:
		_map_highlighter.clear_tile_cursor()


func request_highlight_movement_range(center_pos: Vector2, max_steps: int, style: String) -> void: ## Calculates and highlights all reachable tiles within max_steps.
	if not _map_manager:
		push_warning("GridHighlightRequest: Cannot calculate range, GridMapManager not found.")
		return
	
	if not _map_highlighter:
		return

	# 1. Get the Flood Fill cells from the Map Manager
	var cells = _map_manager.get_cells_in_movement_range(center_pos, max_steps)
	
	# 2. Request the Highlight
	_map_highlighter.add_highlights(style, cells, true)


func request_highlight_directional(center_pos: Vector2, direction: Vector2i, length: int, style: String, stop_on_obstacle: bool = false, highlight_obstacle: bool = false) -> void: ## Highlights a straight line from the center.
	if not _map_manager or not _map_highlighter: return
	
	var cells = _map_manager.get_cells_in_line(center_pos, direction, length, stop_on_obstacle, highlight_obstacle)
	_map_highlighter.add_highlights(style, cells, true)


func request_highlight_sight(center_pos: Vector2, radius: int, style: String, highlight_solid: bool = false) -> void: ## Highlights all visible tiles (Line of Sight).
	if not _map_manager or not _map_highlighter: return
	
	var cells = _map_manager.get_cells_in_sight(center_pos, radius, highlight_solid)
	_map_highlighter.add_highlights(style, cells, true)
