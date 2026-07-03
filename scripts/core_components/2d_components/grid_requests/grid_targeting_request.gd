@icon("uid://bwjs1qno21wss")
class_name GridTargetingRequest
extends Node

## Handles spatial queries and targeting validation against the Grid System.
##
## This component acts as a bridge between an entity (Node2D) and the [GridMapManager].
## It provides high-level questions like "Can I see this target?", "Is this target
## aligned for a charge attack?", or "Who is inside this explosion radius?".[br]
##
## [b]Usage:[/b][br]
## 1. Add as a child node of your entity.[br]
## 2. Assign the [param parent_node] (the "eyes" of the request).[br]
## 3. Call methods like [method can_see_target] or [method is_aligned_cardinally].[br]

# SIGNALS
signal request_failed(reason: String) ## Emitted if the GridMapManager is missing.

# DEPENDENCIES
@export_group("Dependencies")
@export var parent_node: Node2D ## The origin point for all targeting checks.

# CONFIGURATION
@export_group("Settings")
@export var default_sight_range: int = 10 ## Default radius for visibility checks.

# INTERNAL VARIABLES
var _map_manager: GridMapManager


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not parent_node:
		push_error("GridTargetingRequest: No Parent Node assigned.")
		return
	
	_locate_manager()


# PUBLIC FUNCTIONS

func can_see_target(target: Node2D, check_range: int = -1, check_center_only: bool = false) -> bool: ## Checks Line of Sight to a specific Node.
	if not _validate_manager() or not target:
		return false

	var range_limit = check_range if check_range >= 0 else default_sight_range
	var start_pos = parent_node.global_position
	var start_cell = _map_manager.base_tile_map.local_to_map(start_pos)
	
	# FAST PATH: Check center only
	if check_center_only:
		var target_pos = target.global_position
		var target_cell = _map_manager.base_tile_map.local_to_map(target_pos)
		
		# 1. Distance Check
		if Vector2(start_cell).distance_to(Vector2(target_cell)) > range_limit:
			return false
			
		# 2. Raycast
		return _map_manager.has_line_of_sight(start_pos, target_pos)
	
	# COMPLETE PATH: Check all occupied cells
	var target_cells = _get_target_occupied_cells(target)
	
	for cell in target_cells:
		var target_pos = _map_manager.base_tile_map.map_to_local(cell)
		
		# 1. Distance Check (Optimization)
		var dist = Vector2(start_cell).distance_to(Vector2(cell))
		if dist > range_limit:
			continue
			
		# 2. Raycast Check - Return true immediately if ANY part is seen
		if _map_manager.has_line_of_sight(start_pos, target_pos):
			return true
			
	return false


func can_see_target_directional(target: Node2D, direction: Vector2i, max_length: int, stop_at_obstacles: bool = true, check_center_only: bool = false) -> bool: ## Checks if a target is within a directional line (e.g., for a charge attack).
	if not _validate_manager() or not target: return false

	# FAST PATH
	if check_center_only:
		return _map_manager.is_cell_in_directional_range(
			parent_node.global_position, 
			target.global_position, 
			direction, 
			max_length, 
			stop_at_obstacles
		)
	
	# COMPLETE PATH
	var target_cells = _get_target_occupied_cells(target)
	
	for cell in target_cells:
		var target_pos = _map_manager.base_tile_map.map_to_local(cell)
		if _map_manager.is_cell_in_directional_range(parent_node.global_position, target_pos, direction, max_length, stop_at_obstacles):
			return true
			
	return false


func can_see_position(target_pos: Vector2) -> bool: ## Checks Line of Sight to a world position.
	if not _validate_manager(): return false
	return _map_manager.has_line_of_sight(parent_node.global_position, target_pos)


func can_see_position_directional(target_pos: Vector2, direction: Vector2i, max_length: int, stop_at_obstacles: bool = true) -> bool: ## Checks if a target is within a directional line (e.g., for a charge attack).
	if not _validate_manager() or not target_pos: return false
	
	return _map_manager.is_cell_in_directional_range(
		parent_node.global_position,
		target_pos,
		direction,
		max_length,
		stop_at_obstacles
	)


func is_aligned_cardinally(target: Node2D) -> bool: ## Returns true if target is exactly North, South, East, or West.
	if not _validate_manager() or not target: return false
	return _map_manager.is_aligned_cardinal(parent_node.global_position, target.global_position)


func is_aligned_diagonally(target: Node2D) -> bool: ## Returns true if target is exactly diagonal (45 degrees).
	if not _validate_manager() or not target: return false
	return _map_manager.is_aligned_diagonal(parent_node.global_position, target.global_position)


func is_aligned_straight(target: Node2D) -> bool: ## Returns true if target is aligned Cardinally OR Diagonally.
	if not _validate_manager() or not target:
		return false
	
	return _map_manager.is_in_straight_line(parent_node.global_position, target.global_position)


func get_visible_cells(radius: int = -1, include_walls: bool = false) -> Array[Vector2]: ## Returns all visible tile coordinates.
	if not _validate_manager(): return []
	
	var r = radius if radius >= 0 else default_sight_range
	return _map_manager.get_cells_in_sight(parent_node.global_position, r, include_walls)


func get_visible_cells_directional(direction: Vector2i, max_length: int = -1, stop_at_obstacles: bool = true) -> Array[Vector2]:
	if not _validate_manager(): return []
	var r = max_length if max_length >= 0 else default_sight_range
	return _map_manager.get_cells_in_line(parent_node.global_position, direction, r, stop_at_obstacles)


func get_reachable_cells(movement_points: int) -> Array[Vector2]: ## Returns cells reachable via pathfinding (Floodfill).
	if not _validate_manager(): return []
	return _map_manager.get_cells_in_movement_range(parent_node.global_position, movement_points)


func get_cells_in_radius(radius: int) -> Array[Vector2]: ## Returns all cells in a square/circle radius (ignoring walls).
	if not _validate_manager(): return []
	
	return _map_manager.get_cells_in_area(parent_node.global_position, radius)


# PRIVATE FUNCTIONS

func _get_target_occupied_cells(target: Node2D) -> Array[Vector2i]:
	# Recursive search (true) allows finding components nested in visuals/holders
	# 1. Try to find GridInteractive
	var interactives = target.find_children("*", "GridInteractive", true, false)
	if not interactives.is_empty():
		return interactives[0].get_interactive_cells()
	
	# 2. Fallback: Try GridShape
	var shapes = target.find_children("*", "GridShape", true, false)
	if not shapes.is_empty():
		var root = _map_manager.base_tile_map.local_to_map(target.global_position)
		return shapes[0].get_occupied_cells(root)
	
	# 3. Fallback: Single Tile
	var cell = _map_manager.base_tile_map.local_to_map(target.global_position)
	return [cell]


func _locate_manager() -> void:
	var managers = get_tree().get_nodes_in_group("grid_map_manager")
	if managers.size() > 0:
		_map_manager = managers[0]
	else:
		request_failed.emit("GridMapManager not found in group 'grid_map_manager'")


func _validate_manager() -> bool:
	if not _map_manager:
		_locate_manager()
	return _map_manager != null
