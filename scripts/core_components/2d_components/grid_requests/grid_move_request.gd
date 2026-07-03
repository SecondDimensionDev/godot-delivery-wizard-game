@icon("uid://7w58223k1d7a")
class_name GridMoveRequest
extends Node
## Handles movement requests between a parent entity and the Grid System.
##
## This component acts as the bridge between an entity (Node2D), the pathfinder
## (GridMapManager), and the movement logic (GridPathFollow). It validates
## requests and initiates movement if a valid path is found.
## It's crucial to use get_global_mouse_position or global_position, and not event.position.[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add as a child node of the entity you wish to move.[br]
## 2. Assign the 'parent_node' (the moving entity) and 'path_follower' component.[br]
## 3. Ensure a GridMapManager exists in the scene group 'grid_map_manager'.[br]
## 4. Call request_move(destination) to initiate movement.

# SIGNALS
signal move_failed(reason: String) ## Emitted when a move request cannot be fulfilled.
signal path_clamped(original_steps: int, clamped_steps: int) ## Emitted if the path was shortened.


# ENUMS
enum LimitBehavior { 
	NONE, ## Always attempt to move to the destination, regardless of distance.
	REJECT_PATH, ## Fail the move if the destination is outside the max range.
	CLAMP_PATH ## Move as far towards the destination as allowed.
}


# DEPENDENCIES
@export_group("Dependencies")
@export var path_follower: GridPathFollow ## Component responsible for physical movement.
@export var parent_node: Node2D ## The root node of the object being moved.


# CONFIGURATION
@export_group("Movement Rules")
@export var clamp_on_startup: bool = false ## Should the parent node be clamped to the closest grid position.
@export var limit_behavior: LimitBehavior = LimitBehavior.NONE ## How to handle paths exceeding max range.
@export var max_steps: int = 5 ## Maximum grid cells the entity can move (if behavior is set).


# INTERNAL VARIABLES
var _map_manager: GridMapManager ## Reference to the global grid manager.


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	# Verify Dependencies
	if not path_follower:
		push_error("No GridPathFollow assigned!")
		set_process_unhandled_input(false)
		return
		
	if not parent_node:
		push_error("No Parent assigned!")
		set_process_unhandled_input(false)
		return
		
	# Locate Grid Manager via Group
	var grid_managers := get_tree().get_nodes_in_group("grid_map_manager")
	if grid_managers.size() > 0:
		_map_manager = grid_managers[0]
		if grid_managers.size() > 1:
			push_warning("Multiple GridMapManagers found, only 1 required per level")
	else:
		push_warning("No GridMapManager Assigned. Make sure it's in the group 'grid_map_manager'.")
	
	if clamp_on_startup and _map_manager:
		var snapped_pos = _map_manager.get_closest_tile_position(parent_node.global_position)
		parent_node.global_position = snapped_pos


# PUBLIC METHODS

func check_path(destination: Vector2) -> Array: ## Returns the potential path to a destination without moving.
	var local_pos = _map_manager.base_tile_map.to_local(destination)
	var map_coords = _map_manager.base_tile_map.local_to_map(local_pos)
	var center_local = _map_manager.base_tile_map.map_to_local(map_coords)
	
	if parent_node.global_position == center_local:
		return []
	
	if not _map_manager: 
		return []
	
	var start_pos := parent_node.global_position
	var target_pos := destination
	
	var path_points := _map_manager.get_path_world(start_pos, target_pos)
	return _apply_limit_logic(path_points)


func request_move(destination: Vector2, append_path: bool = false) -> void: ## Requests movement to the destination, append path will queue destination.
	if not _map_manager:
		move_failed.emit("GridMapManager unavailable")
		return

	var start_pos := parent_node.global_position
	if append_path:
		start_pos = path_follower.get_final_destination()
	
	var path_points := _map_manager.get_path_world(start_pos, destination)
	
	if path_points.is_empty():
		# Debug failure reason
		if not _map_manager.is_tile_solid(destination):
			move_failed.emit("Destination unreachable")
		else:
			move_failed.emit("Destination blocked or out of bounds")
		return
	
	var processed_path = _apply_limit_logic(path_points)
	
	if processed_path.is_empty():
		move_failed.emit("Path rejected due to limit")
		return
		
	if append_path:
		path_follower.append_path(processed_path)
	else:
		path_follower.move_along_path(processed_path)


func request_stop(emergency_stop: bool = false) -> void: ## Request stop at the next safe point, unless emergency stop is requested
	if not path_follower:
		return
	path_follower.stop_movement(emergency_stop)


func get_cells_in_movement_range(movement_points: int = max_steps) -> Array[Vector2]: ## Returns cells in movement range.
	if not _map_manager:
		return []
	
	return _map_manager.get_cells_in_movement_range(parent_node.global_position, movement_points)


# PRIVATE METHODS

func _apply_limit_logic(path: Array[Vector2]) -> Array[Vector2]:
	# AStarGrid2D paths usually include the start point? 
	# GridMapManager.get_path_world iterates the ID path.
	# Standard AStarGrid2D includes the starting cell. 
	# So a move of 1 step has a path size of 2 (Start -> End).
	# Therefore, steps = size - 1.
	
	if limit_behavior == LimitBehavior.NONE:
		return path
		
	var step_count = path.size() 
	# Note: Depending on your exact GridMapManager implementation, 
	# check if index 0 is the current position. 
	# Assuming path[0] == current_pos, steps = size - 1.
	
	if step_count - 1 <= max_steps:
		return path
		
	if limit_behavior == LimitBehavior.REJECT_PATH:
		return []
		
	if limit_behavior == LimitBehavior.CLAMP_PATH:
		# We need to keep the start point + max_steps
		var allowed_size = max_steps + 1
		var clamped_path = path.slice(0, allowed_size)
		path_clamped.emit(step_count - 1, max_steps)
		return clamped_path
		
	return path
