@icon("uid://ck81ci7aj1bap")
class_name GridMapManager
extends Node
## Central manager for the grid and pathfinding logic.
##
## This script initializes an AStarGrid2D based on a TileMapLayer. It detects
## obstacles from specified layers and provides a public API for path requests.[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add to the main scene.[br]
## 2. Assign 'base_tile_map' (defines the grid bounds and cell size).[br]
## 3. Add any obstacle layers to 'obstacle_layers'.[br]
## 4. Ensure any layers used have a custom data property called is_solid of type boolean.[br]
## 5. Call get_path_world(start, end) from other scripts to get a movement path.

# CONFIGURATION
@export_group("Grid Setup")
@export var geometry_type: AStarGrid2D.CellShape = AStarGrid2D.CellShape.CELL_SHAPE_SQUARE ## Shape of the grid cells (Square/Hex/Iso).
@export var base_tile_map: TileMapLayer ## The reference map used for grid bounds and sizing.
@export var obstacle_layers: Array[TileMapLayer] = [] ## Layers that contain collision/blocking tiles.

@export_group("Pathfinding Setup")
@export var diagonal_mode: AStarGrid2D.DiagonalMode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES ## Rules for diagonal movement.
@export var default_heuristic: AStarGrid2D.Heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN ## Heuristic for path cost calculation.
@export var clamp_bounds_method: ClampBoundsMethod = ClampBoundsMethod.CHECK ## Should path requests clamp the request to the bounds of the tilemap

@export_group("Line of Sight Setup")
@export var line_of_sight_shape: LOSRangeShape = LOSRangeShape.SQUARE ## What shape to use when calling grid line of sight checks
@export_range(0.00, 0.50,0.01) var line_of_sight_smoothing: float = 0.15 ## How much to smooth the line of sight range when a circlar shape is used

@export_group("Override Cell Size")
@export var override_cell_size: Vector2i = Vector2i(0, 0) ## Manual override for cell size (leave 0,0 for auto).

# INTERNAL VARIABLES
var _astar: AStarGrid2D ## The internal AStar pathfinding instance.
var _dynamic_blocker_counts: Dictionary = {} ## Tracks how many dynamic objects are on a specific cell.

# ENUMS
enum ClampBoundsMethod {ALWAYS, NEVER, CHECK} ## Defines methods of clamping path requests to the bounds of the tilemap
enum LOSRangeShape {SQUARE, CIRCLE} ## Should the Grid Line of Sight range be a square or a circle?

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	add_to_group("grid_map_manager")
	
	if not base_tile_map:
		push_error("GridMapManager: No TileMap assigned!")
		return
	_initialize_grid()


# PUBLIC METHODS

func get_path_world(start_pos: Vector2, end_pos: Vector2, clamp_inside_bounds: bool = false) -> Array[Vector2]: ## Calculates and returns a path of world coordinates.
	if not base_tile_map or not _astar:
		push_error("GridMapManager: No Base TileMap assigned!")
		return []
	
	var clamp_bounds: bool = clamp_inside_bounds
	var start_cell := base_tile_map.local_to_map(start_pos)
	var end_cell := base_tile_map.local_to_map(end_pos)
	
	if start_cell == end_cell:
		return [base_tile_map.map_to_local(end_cell)]
	
	if clamp_bounds_method == ClampBoundsMethod.ALWAYS:
		clamp_bounds = true
	
	if clamp_bounds_method == ClampBoundsMethod.NEVER:
		clamp_bounds = false
	
	# Pull out-of-bounds requests back onto the grid, can be override by clamp_bounds_method
	if clamp_bounds:
		var region = _astar.region
		# region.end is exclusive, so we subtract 1 for the max index
		start_cell.x = clampi(start_cell.x, region.position.x, region.end.x - 1)
		start_cell.y = clampi(start_cell.y, region.position.y, region.end.y - 1)
		
		end_cell.x = clampi(end_cell.x, region.position.x, region.end.x - 1)
		end_cell.y = clampi(end_cell.y, region.position.y, region.end.y - 1)

	# Verify bounds
	if not _astar.is_in_boundsv(start_cell) or not _astar.is_in_boundsv(end_cell):
		return []

	var id_path := _astar.get_id_path(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	
	for cell in id_path:
		var world_pos := base_tile_map.map_to_local(cell)
		world_path.append(world_pos)
		
	return world_path


func is_tile_solid(world_pos: Vector2) -> bool: ## Checks if a specific world position contains an obstacle.
	var cell := base_tile_map.local_to_map(world_pos)
	
	if not _astar.region.has_point(cell):
		return true
		
	return _astar.is_point_solid(cell)


func set_single_tile_solid(world_pos: Vector2, is_solid: bool) -> void: ## Manually updates the solid state of a tile.
	if not _astar: 
		return
	
	var cell := base_tile_map.local_to_map(world_pos)
	
	if _astar.region.has_point(cell):
		_astar.set_point_solid(cell, is_solid)


func set_multiple_tiles_solid(world_positions: Array[Vector2], is_solid: bool) -> void: ## Sets the solid state for a list of specific cooridnates.
	for pos in world_positions:
		set_single_tile_solid(pos, is_solid)


func set_region_solid(region_rect: Rect2, is_solid: bool) -> void: ## Sets the solid state for all tiles within a world-space rectangle.
	if not base_tile_map:
		return

	# Convert world rect corners to map coordinates
	var start_cell := base_tile_map.local_to_map(region_rect.position)
	var end_cell := base_tile_map.local_to_map(region_rect.end)
	
	# Loop through x and y range
	# Note: We use min/max to handle rects drawn with negative size
	var x_min = min(start_cell.x, end_cell.x)
	var x_max = max(start_cell.x, end_cell.x)
	var y_min = min(start_cell.y, end_cell.y)
	var y_max = max(start_cell.y, end_cell.y)

	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			var cell_pos := Vector2i(x, y)
			if _astar.region.has_point(cell_pos):
				_astar.set_point_solid(cell_pos, is_solid)


func get_world_bounds() -> Rect2: ## Returns the bounds of the used base tilemap
	if not base_tile_map:
		return Rect2()
	
	if not base_tile_map.tile_set:
		push_warning("GridMapManager: TileMap has no TileSet assigned.")
		return Rect2()
		
	# Calculate total pixel bounds of the map
	var map_rect := base_tile_map.get_used_rect()
	var tile_size := base_tile_map.tile_set.tile_size
	
	# Convert Grid Coords to World Pixel Rect
	var world_bounds := Rect2(
		map_rect.position * tile_size, 
		map_rect.size * tile_size
	)
	return world_bounds


func get_closest_tile_position(world_pos: Vector2) -> Vector2: ## Snaps a world position to the center of the nearest grid cell.
	if not base_tile_map:
		return world_pos
	
	var cell := base_tile_map.local_to_map(world_pos)
	return base_tile_map.map_to_local(cell)


func register_dynamic_blocker(world_pos: Vector2) -> void: ## Registers an object blocking this tile. Increments the blocker count.
	var cell := base_tile_map.local_to_map(world_pos)
	
	if not _dynamic_blocker_counts.has(cell):
		_dynamic_blocker_counts[cell] = 0
		
	_dynamic_blocker_counts[cell] += 1
	
	# If this is the first blocker, make the grid solid
	if _dynamic_blocker_counts[cell] == 1:
		_astar.set_point_solid(cell, true)


func unregister_dynamic_blocker(world_pos: Vector2) -> void: ## Unregisters an object. If count drops to 0, checks if the tile should be freed.
	var cell := base_tile_map.local_to_map(world_pos)
	
	if not _dynamic_blocker_counts.has(cell):
		return
		
	_dynamic_blocker_counts[cell] -= 1
	
	# If no dynamic blockers remain, we need to check if we can open the tile
	if _dynamic_blocker_counts[cell] <= 0:
		_dynamic_blocker_counts.erase(cell)
		
		# CHECK: Is this tile ALSO blocked by the static TileMap?
		# We re-check the original static layer logic before opening it.
		if not _is_static_layer_solid(cell):
			_astar.set_point_solid(cell, false)


func get_cells_in_movement_range(start_pos: Vector2, max_steps: int) -> Array[Vector2]: 
	## Returns all reachable cells within max_steps, accounting for obstacles and diagonal rules.
	if not _astar or not base_tile_map:
		return []
	
	var start_cell := base_tile_map.local_to_map(start_pos)
	
	if not _astar.region.has_point(start_cell) or _astar.is_point_solid(start_cell):
		return []
	
	var reachable_cells: Array[Vector2] = []
	
	# BFS Structures
	var queue: Array = [] 
	var visited: Dictionary = {} 
	
	queue.append([start_cell, 0])
	visited[start_cell] = 0
	
	# Define Directions
	var dirs_cardinal = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var dirs_diagonal = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	
	var allow_diagonal = _astar.diagonal_mode != AStarGrid2D.DIAGONAL_MODE_NEVER
	
	while not queue.is_empty():
		var current_data = queue.pop_front()
		var current_cell: Vector2i = current_data[0]
		var current_cost: int = current_data[1]
		
		# Add to results (skip start cell visual if desired, but usually we include it)
		if current_cost > 0:
			reachable_cells.append(base_tile_map.map_to_local(current_cell))
		
		# Stop expanding if we hit the limit
		if current_cost >= max_steps:
			continue
			
		# 1. Process Cardinal Neighbors
		for dir in dirs_cardinal:
			_process_neighbor(current_cell, dir, current_cost, queue, visited)
		
		# 2. Process Diagonal Neighbors (if enabled)
		if allow_diagonal:
			for dir in dirs_diagonal:
				# Check specifically for "Corner Cutting" rules before adding
				if _is_diagonal_valid(current_cell, dir):
					_process_neighbor(current_cell, dir, current_cost, queue, visited)
			
	return reachable_cells


func get_cells_in_line(start_pos: Vector2, direction: Vector2i, length: int, stop_at_obstacles: bool = true, include_walls: bool = false) -> Array[Vector2]: ## Returns a straight line of cells. direction should be a normalized grid vector (e.g. 1,0 or 1,1)
	if not base_tile_map: return []

	var start_cell := base_tile_map.local_to_map(start_pos)
	var result: Array[Vector2] = []
	
	for i in range(1, length + 1):
		var next_cell = start_cell + (direction * i)
		
		# Check Bounds
		if _astar and not _astar.region.has_point(next_cell):
			break
			
		# Check Obstacles (Optional)
		if stop_at_obstacles and _astar and _astar.is_point_solid(next_cell):
			if include_walls:
				result.append(base_tile_map.map_to_local(next_cell))
			break
			
		result.append(base_tile_map.map_to_local(next_cell))
		
	return result


func get_cells_in_sight(start_pos: Vector2, range_limit: int, include_walls: bool = false) -> Array[Vector2]: ## Returns all cells visible from start_pos within range (blocked by walls)
	if not base_tile_map or not _astar: return []

	var start_cell := base_tile_map.local_to_map(start_pos)
	var visible_cells: Array[Vector2] = []
	var make_range_circular: bool = false
	var los_range_smoothing_value: float = 0
	
	if line_of_sight_shape == LOSRangeShape.CIRCLE:
		make_range_circular = true
		los_range_smoothing_value = range_limit * line_of_sight_smoothing
	
	# Loop through the bounding box defined by range_limit
	for x in range(-range_limit, range_limit + 1):
		for y in range(-range_limit, range_limit + 1):
			var offset = Vector2i(x, y)
			var target_cell = start_cell + offset
			
			# 1. Skip if out of circular range (optional, makes it a circle instead of square)
			if make_range_circular and offset.length() > (range_limit + los_range_smoothing_value):
				continue
				
			# 2. Skip if out of bounds
			if not _astar.region.has_point(target_cell):
				continue
				
			# 3. Raycast Check: Can we see this tile?
			if _run_bresenham_check(start_cell, target_cell):
				if not include_walls and _astar.is_point_solid(target_cell):
					continue
				visible_cells.append(base_tile_map.map_to_local(target_cell))

	return visible_cells


func get_cells_in_area(start_pos: Vector2, range_limit: int) -> Array[Vector2]:
	if not base_tile_map or not _astar: return []

	var start_cell := base_tile_map.local_to_map(start_pos)
	var area_cells: Array[Vector2] = []
	var make_range_circular: bool = false
	var los_range_smoothing_value: float = 0
	
	if line_of_sight_shape == LOSRangeShape.CIRCLE:
		make_range_circular = true
		los_range_smoothing_value = range_limit * line_of_sight_smoothing
	
	for x in range(-range_limit, range_limit + 1):
		for y in range(-range_limit, range_limit + 1):
			var offset = Vector2i(x, y)
			var target_cell = start_cell + offset
			
			# 1. Skip if out of circular range
			if make_range_circular and offset.length() > (range_limit + los_range_smoothing_value):
				continue
				
			# 2. Skip if out of bounds
			if not _astar.region.has_point(target_cell):
				continue
			
			area_cells.append(base_tile_map.map_to_local(target_cell))
	
	return area_cells


func has_line_of_sight(start_pos: Vector2, target_pos: Vector2) -> bool: ## Checks if a line exists between start and target without hitting obstacles.
	
	if not base_tile_map or not _astar: 
		return false
	
	var start_cell := base_tile_map.local_to_map(start_pos)
	var end_cell := base_tile_map.local_to_map(target_pos)
	
	return _run_bresenham_check(start_cell, end_cell)


func is_cell_in_directional_range(start_pos: Vector2, target_pos: Vector2, direction: Vector2i, length: int, stop_at_obstacles: bool = true) -> bool: ## Checks if the target lies on a specific directional line of a given length.
	if not base_tile_map or not _astar: 
		return false
		
	var start_cell := base_tile_map.local_to_map(start_pos)
	var target_cell := base_tile_map.local_to_map(target_pos)
	
	if start_cell == target_cell:
		return false

	var diff = target_cell - start_cell
	
	# 1. Check Alignment & Distance via scalar projection
	# We try to find a scalar 'k' such that: target = start + (dir * k)
	var k: int = -1
	
	if direction.x != 0:
		if diff.x % direction.x != 0: return false # Not an integer step
		k = diff.x / direction.x
		
		# If Y is also used (diagonal), it must match the same 'k'
		if direction.y != 0:
			if diff.y % direction.y != 0 or diff.y / direction.y != k:
				return false
				
	elif direction.y != 0:
		if diff.y % direction.y != 0: return false
		k = diff.y / direction.y
	else:
		return false # Direction is (0,0) which is invalid

	# 2. Check Range Limits
	# k must be positive (in front of us) and within the length
	if k <= 0 or k > length:
		return false
		
	# 3. Check Obstacles (if required)
	if stop_at_obstacles:
		# We can reuse the Bresenham check because we know it's a straight line
		if not _run_bresenham_check(start_cell, target_cell):
			return false
			
	return true


func is_aligned_cardinal(start_pos: Vector2, target_pos: Vector2) -> bool: ## Returns true if the target is exactly North, South, East, or West.
	var start_cell := base_tile_map.local_to_map(start_pos)
	var end_cell := base_tile_map.local_to_map(target_pos)
	
	return start_cell.x == end_cell.x or start_cell.y == end_cell.y


func is_aligned_diagonal(start_pos: Vector2, target_pos: Vector2) -> bool: ## Returns true if the target is exactly diagonal (45 degrees).
	var start_cell := base_tile_map.local_to_map(start_pos)
	var end_cell := base_tile_map.local_to_map(target_pos)
	var diff = (end_cell - start_cell).abs()
	
	return diff.x == diff.y


func is_in_straight_line(start_pos: Vector2, target_pos: Vector2) -> bool: ## Returns true if the target is aligned either Cardinally or Diagonally.
	return is_aligned_cardinal(start_pos, target_pos) or is_aligned_diagonal(start_pos, target_pos)


# PRIVATE METHODS

func _initialize_grid() -> void: # Initial setup of the Grid
	_astar = AStarGrid2D.new()
	
	# Auto-Size Logic
	if override_cell_size == Vector2i.ZERO:
		if base_tile_map.tile_set:
			_astar.cell_size = base_tile_map.tile_set.tile_size
		else:
			push_error("GridMapManager: TileMap has no TileSet assigned!")
			return
	else:
		_astar.cell_size = override_cell_size
	
	# Apply Settings
	_astar.cell_shape = geometry_type
	_astar.diagonal_mode = diagonal_mode
	_astar.default_compute_heuristic = default_heuristic
	_astar.default_estimate_heuristic = default_heuristic
	
	# Set Region
	var map_rect := base_tile_map.get_used_rect()
	_astar.region = map_rect
	_astar.update() 
	
	_scan_for_obstacle_tiles()


func _scan_for_obstacle_tiles() -> void: # Check obstacle tilesets for is_solid property
	for layer in obstacle_layers:
		if not layer: continue
		
		for cell_pos in layer.get_used_cells():
			var tile_data := layer.get_cell_tile_data(cell_pos)
			
			if tile_data and tile_data.get_custom_data("is_solid"):
				if _astar.region.has_point(cell_pos):
					_astar.set_point_solid(cell_pos, true)


func _is_static_layer_solid(cell: Vector2i) -> bool: # Helper to check if the base TileLayers have an obstacle here.
	for layer in obstacle_layers:
		if not layer: continue
		var tile_data := layer.get_cell_tile_data(cell)
		if tile_data and tile_data.get_custom_data("is_solid"):
			return true
	return false


func _process_neighbor(current: Vector2i, dir: Vector2i, cost: int, queue: Array, visited: Dictionary) -> void: # Helper to pricess neighbours when using floor fill functions for movement ranges
	var next_cell = current + dir
	var next_cost = cost + 1
	
	# Check Bounds
	if not _astar.region.has_point(next_cell):
		return
		
	# Check Obstacles
	if _astar.is_point_solid(next_cell):
		return
		
	# Check Visited
	if visited.has(next_cell) and visited[next_cell] <= next_cost:
		return
		
	visited[next_cell] = next_cost
	queue.append([next_cell, next_cost])


func _is_diagonal_valid(current: Vector2i, direction: Vector2i) -> bool: # Internal Helper to check if a diagonal move is allowed by geometry
	# Calculate the two "adjacent" cardinal neighbors involved in this diagonal move
	# e.g. If moving (1, 1) [Down-Right], neighbors are (1, 0) [Right] and (0, 1) [Down]
	var neighbor_x = current + Vector2i(direction.x, 0)
	var neighbor_y = current + Vector2i(0, direction.y)
	
	var solid_x = _astar.is_point_solid(neighbor_x) if _astar.region.has_point(neighbor_x) else true
	var solid_y = _astar.is_point_solid(neighbor_y) if _astar.region.has_point(neighbor_y) else true
	
	# Check based on the active mode
	match _astar.diagonal_mode:
		AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES:
			# Strict: Can only move diagonally if BOTH adjacent cardinals are empty
			if solid_x or solid_y:
				return false
				
		AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE:
			# Permissive: Can move if AT LEAST ONE adjacent cardinal is empty
			if solid_x and solid_y:
				return false
				
		# DIAGONAL_MODE_ALWAYS ignores corners, so we just return true
		
	return true


func _run_bresenham_check(start: Vector2i, end: Vector2i) -> bool: #Internal helper to calculate line of sight on a grid, using Bresenham's Line Algorithm
	# Bresenham's Line Algorithm implementation for Grid Traversal
	var x0 = start.x
	var y0 = start.y
	var x1 = end.x
	var y1 = end.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		var current = Vector2i(x0, y0)
		
		# If we hit a wall (and it's not the start or end point), sight is blocked
		# Note: We usually allow seeing the wall itself, but not past it.
		if current != start and _astar.is_point_solid(current):
			# If this blocked tile is the target, we can "see" it (the wall itself).
			# If it's somewhere in the middle, the path is blocked.
			if current == end:
				return true
			else:
				return false
				
		if current == end:
			return true
			
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
			
	return true
