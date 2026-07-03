class_name LinearMapManager
extends Node

## Manages linear map generation, data persistence, and logic.
##
## This node does not handle visuals. It generates [LinearMapNodeData] and notifies 
## listeners (like LinearMapDisplay) when the map changes.

# SIGNALS
signal map_generated ## Emitted when generation is complete.
signal player_moved(new_location_id: String) ## Emitted when the player officially changes nodes.
signal map_data_updated ## Emitted when status changes (load this to refresh display).

# ENUMS
enum MapOrientation { LEFT_TO_RIGHT, TOP_TO_BOTTOM }
enum SingleNodeSequence { STANDARD, REDUCED, NEVER }
enum EndPointPosition { MIDDLE, TOP, BOTTOM, RANDOM }

# EXPORT VARIABLES
@export_group("Map Settings")
@export var orientation: MapOrientation = MapOrientation.LEFT_TO_RIGHT
@export var grid_steps: int = 5 ## Number of steps or stages on the path (grid columns when running left to right)
@export var grid_breadth: int = 3 ## Number of grid spaces at each map grid step (grid rows when running left to right)
@export var connection_reach: int = 1 ## How many rows up/down a path can deviate.
@export var max_locations_per_row: int = 3

@export_group("Generation Rules")
@export var rng_seed: int = 0 ## 0 for random.
@export var single_node_sequence: SingleNodeSequence = SingleNodeSequence.STANDARD ## Controls frequency of consecutive single-node columns.
@export var start_node_position: EndPointPosition = EndPointPosition.MIDDLE ## Vertical position of the first node.
@export var end_node_position: EndPointPosition = EndPointPosition.MIDDLE ## Vertical position of the last node.
@export var target_node_count: int = 0 ## Try to generate exactly this many nodes. 0 = Random/Unlimited.
@export var content_generator: BaseLocationDataGenerator ## The game-specific logic for populating nodes.

# PUBLIC VARIABLES
var all_nodes: Dictionary = {} ## Map of ID (String) -> LinearMapNodeData
var current_player_node_id: String = ""

# PRIVATE VARIABLES
var _rng = RandomNumberGenerator.new()
var _active_target_count: int = 0
var _current_node_count: int = 0


# BUILT-IN VIRTUAL FUNCTIONS
func _ready() -> void:
	# Wake up and check the global session data
	await get_tree().process_frame
	if SessionManager.current_run:
		if not SessionManager.current_run.map_data.is_empty():
			# We have existing map data in this run, load it!
			load_map_data(SessionManager.current_run.map_data)
		else:
			# It's a fresh run with no map data yet, generate one!
			await get_tree().process_frame
			generate_map()
	else:
		await get_tree().process_frame
		generate_map()


# PUBLIC FUNCTIONS
func generate_map() -> void: ## Runs the generation algorithm.
	all_nodes.clear()
	_current_node_count = 0
	
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	
	# Validate Target Count against physical limits
	_validate_target_node_count()
	
	var columns_data: Array[Array] = []
	
	# 1. Create Nodes Column by Column
	for col in range(grid_steps):
		var col_nodes := _generate_nodes_for_column(col, columns_data)
		columns_data.append(col_nodes)
	
	# 2. Create Standard Connections (Forward Neighbor Algorithm)
	for col_idx in range(columns_data.size() - 1):
		_connect_columns(columns_data[col_idx], columns_data[col_idx + 1])
	
	# 3. Repair Orphans (Ensure every node has a backward connection)
	_repair_orphaned_nodes(columns_data)
	
	# 4. Set Initial State
	_set_initial_map_state(columns_data)
	
	_sync_map_to_session()
	map_generated.emit()


func get_map_save_data() -> Dictionary: ## Packages the current map state for the SessionManager
	return {
		"nodes": all_nodes,
		"current_node_id": current_player_node_id
	}


func load_map_data(data_dictionary: Dictionary) -> void: ## Loads state from GameSessionData.
	if data_dictionary.is_empty():
		return
		
	all_nodes = data_dictionary.get("nodes", {})
	current_player_node_id = data_dictionary.get("current_node_id", "")
	
	# 1. Tell the display to completely rebuild the visual nodes
	map_generated.emit() 
	
	# 2. Tell the display where the player is, DEFERRED so the nodes exist first!
	if current_player_node_id != "":
		_broadcast_initial_player_position.call_deferred(current_player_node_id)


func attempt_move_player(target_node_id: String) -> bool: ## Validates and moves player.
	var target_node = all_nodes.get(target_node_id)
	
	if not target_node:
		push_warning("LinearMapManager: Invalid node ID %s" % target_node_id)
		return false
	
	# We can only move to AVAILABLE nodes
	if target_node.status != LinearMapNodeData.LocationStatus.AVAILABLE:
		return false 
	
	# Update Logic
	current_player_node_id = target_node_id
	
	# Perform the status updates across the map based on the new position
	_update_map_states_after_move(target_node)
	
	_sync_map_to_session()
	player_moved.emit(target_node_id)
	map_data_updated.emit()
	return true


func complete_current_level() -> void: ## Call this when the player wins/clears the current node.
	var current_node = all_nodes.get(current_player_node_id)
	if not current_node: return
	
	current_node.status = LinearMapNodeData.LocationStatus.CURRENT_COMPLETE
	_unlock_next_nodes(current_node)
	map_data_updated.emit()


# PRIVATE FUNCTIONS
func _sync_map_to_session() -> void: # Pushes the current map state to the global run data
	if SessionManager.current_run:
		SessionManager.current_run.map_data = {
			"nodes": all_nodes,
			"current_node_id": current_player_node_id
		}
		SessionManager.save_run()


func _validate_target_node_count() -> void:
	# Reset active target
	_active_target_count = target_node_count
	
	if _active_target_count <= 0:
		return

	# Calculate theoretical limits
	var min_nodes = grid_steps # Minimum 1 per column
	
	# Start(1) + End(1) + Middle columns * Max
	var max_middle_cols = max(0, grid_steps - 2)
	var effective_max_per_row = mini(grid_breadth, max_locations_per_row)
	var max_nodes = 2 + (max_middle_cols * effective_max_per_row)

	if _active_target_count < min_nodes:
		push_warning("LinearMapManager: Target count %d is too low for grid size. Clamping to %d." % [_active_target_count, min_nodes])
		_active_target_count = min_nodes
	elif _active_target_count > max_nodes:
		push_warning("LinearMapManager: Target count %d is too high for rules. Clamping to %d." % [_active_target_count, max_nodes])
		_active_target_count = max_nodes


func _generate_nodes_for_column(col_index: int, existing_columns: Array[Array]) -> Array[LinearMapNodeData]:
	var col_nodes: Array[LinearMapNodeData] = []
	var is_start = (col_index == 0)
	var is_end = (col_index == grid_steps - 1)
	
	if is_start or is_end:
		# Position based on specific setting
		var setting = start_node_position if is_start else end_node_position
		var row = _get_start_end_row_index(setting)
		
		var node = _create_node_data(col_index, row)
		col_nodes.append(node)
		all_nodes[node.id] = node
		_current_node_count += 1
	else:
		# Determine how many nodes to spawn in this column
		var previous_count = 1
		if not existing_columns.is_empty():
			previous_count = existing_columns.back().size()
			
		var count = _calculate_node_count(col_index, previous_count)
		
		# Pick unique rows
		var available_rows = range(grid_breadth)
		available_rows.shuffle()
		
		for i in range(count):
			var row = available_rows.pop_front()
			var node = _create_node_data(col_index, row)
			col_nodes.append(node)
			all_nodes[node.id] = node
			_current_node_count += 1

		# Sort by row index to make connection logic cleaner
		col_nodes.sort_custom(func(a, b): return a.grid_position.y < b.grid_position.y)
		
	return col_nodes


func _calculate_node_count(current_col_index: int, previous_col_count: int) -> int:
	var effective_max = mini(grid_breadth, max_locations_per_row)
	var min_count = 1
	
	# 1. Apply Choke Point Logic (Single Node Sequence)
	if previous_col_count == 1:
		match single_node_sequence:
			SingleNodeSequence.NEVER:
				min_count = 2
			SingleNodeSequence.REDUCED:
				if _rng.randf() > 0.5:
					min_count = 2
	
	min_count = mini(min_count, effective_max)
	
	# 2. Random Generation
	var calculated_count = _rng.randi_range(min_count, effective_max)
	
	# 3. Apply "Budget" Logic if target is set
	if _active_target_count > 0:
		# How many columns are left to fill? (excluding current and end node which is fixed to 1)
		var remaining_middle_cols = (grid_steps - 1) - current_col_index
		
		# How many nodes do we still need? (Reserve 1 for the end node)
		var nodes_needed = _active_target_count - _current_node_count - 1
		
		if remaining_middle_cols > 0:
			# Calculate ideal average needed per column to hit target
			var ideal_avg = float(nodes_needed) / float(remaining_middle_cols)
			
			# Round to nearest int but add some variance so it doesn't feel robotic
			# e.g. if we need 2.5 per row, flip a coin between 2 and 3
			var base = floor(ideal_avg)
			if _rng.randf() < (ideal_avg - base):
				calculated_count = base + 1
			else:
				calculated_count = base
			
			# Hard clamp to ensure we don't violate physics or the previous Choke Point rules
			calculated_count = clampi(calculated_count, min_count, effective_max)
	
	return calculated_count


func _get_start_end_row_index(setting: EndPointPosition) -> int:
	match setting:
		EndPointPosition.TOP:
			return 0
		EndPointPosition.BOTTOM:
			return grid_breadth - 1
		EndPointPosition.RANDOM:
			return _rng.randi_range(0, grid_breadth - 1)
		_: # MIDDLE
			return floor(grid_breadth / 2.0)


func _create_node_data(col: int, row: int) -> LinearMapNodeData:
	var new_data = LinearMapNodeData.new()
	new_data.id = "%d_%d" % [col, row]
	new_data.grid_position = Vector2i(col, row)
	new_data.status = LinearMapNodeData.LocationStatus.LOCKED
	if content_generator:
		content_generator.populate_node_content(new_data, col, grid_breadth)
	else:
		push_warning("LinearMapManager: No RunContentInjector assigned. Creating blank location data.")
		new_data.location_contents = BaseMapLocationContents.new()
	return new_data


func _connect_columns(current_col: Array, next_col: Array) -> void:
	for source_node in current_col:
		var candidates = []
		
		# [cite_start]Find candidates within reach [cite: 15]
		for target in next_col:
			var dist = abs(source_node.grid_position.y - target.grid_position.y)
			if dist <= connection_reach:
				candidates.append(target)
		
		# Fallback: If no node is within reach, connect to closest to ensure forward path
		if candidates.is_empty():
			var closest = _find_closest_node(source_node, next_col)
			if closest:
				candidates.append(closest)

		# Apply connections
		for target in candidates:
			source_node.add_connection(target.id)


#func _connect_node_to_column(source_node: LinearMapNodeData, next_col_nodes: Array) -> void:
	#var candidates = []
	#
	## Find candidates within reach
	#for target in next_col_nodes:
		#var dist = abs(source_node.grid_position.y - target.grid_position.y)
		#if dist <= connection_reach:
			#candidates.append(target)
	#
	## Fallback: If no node is within reach (e.g. extreme gap), connect to closest
	#if candidates.is_empty():
		#var closest = next_col_nodes[0]
		#var min_dist = 999
		#for target in next_col_nodes:
			#var dist = abs(source_node.grid_position.y - target.grid_position.y)
			#if dist < min_dist:
				#min_dist = dist
				#closest = target
		#candidates.append(closest)
		#
	## Ensure we don't connect to ALL candidates if there are many, 
	## but ensure we connect to at least one.
	## For now, simply connecting to all valid candidates within reach is standard for this graph type.
	#for target in candidates:
		#source_node.add_connection(target.id)


func _update_map_states_after_move(new_current_node: LinearMapNodeData) -> void:
	
	# 1. Iterate through ALL nodes to handle Past, Present, and "Reset" Future
	for id in all_nodes:
		var node = all_nodes[id] as LinearMapNodeData
		
		# A. PAST NODES (Columns behind the player)
		if node.grid_position.x < new_current_node.grid_position.x:
			if node.status == LinearMapNodeData.LocationStatus.CURRENT_COMPLETE:
				node.status = LinearMapNodeData.LocationStatus.VISITED
			elif node.status == LinearMapNodeData.LocationStatus.VISITED:
				pass # Already visited, leave it
			else:
				# CRITICAL CHANGE: Only mark as SKIPPED if it wasn't already UNREACHABLE.
				# If it was UNREACHABLE, it stays that way (it was never an option).
				if node.status != LinearMapNodeData.LocationStatus.UNREACHABLE:
					node.status = LinearMapNodeData.LocationStatus.SKIPPED
		
		# B. PRESENT NODES (Same column as player)
		elif node.grid_position.x == new_current_node.grid_position.x:
			if node == new_current_node:
				node.status = LinearMapNodeData.LocationStatus.CURRENT_INCOMPLETE
			else:
				# Siblings in the current column.
				# Again, preserve UNREACHABLE if they were never connected.
				if node.status != LinearMapNodeData.LocationStatus.UNREACHABLE:
					node.status = LinearMapNodeData.LocationStatus.SKIPPED
		
		# C. FUTURE NODES (Columns ahead of player)
		else:
			# Reset ALL future nodes to UNREACHABLE first.
			# We will "paint" the valid ones back to LOCKED in step 2.
			node.status = LinearMapNodeData.LocationStatus.UNREACHABLE
		
	# 2. Paint valid future paths
	# Identify immediate neighbors (Next Locked)
	for next_id in new_current_node.connected_to_ids:
		var next_node = all_nodes.get(next_id)
		if next_node:
			next_node.status = LinearMapNodeData.LocationStatus.NEXT_LOCKED
			# From these neighbors, recursively mark subsequent nodes as LOCKED
			_mark_valid_future_nodes(next_node)


func _refresh_reachability(start_node: LinearMapNodeData) -> void:
	for next_id in start_node.connected_to_ids:
		var next_node = all_nodes.get(next_id)
		if next_node:
			# If we are looking at immediate neighbors of current, they are NEXT_LOCKED
			# If we are looking further ahead, they are LOCKED
			if next_node.status == LinearMapNodeData.LocationStatus.UNREACHABLE:
				next_node.status = LinearMapNodeData.LocationStatus.LOCKED
				_refresh_reachability(next_node)


func _unlock_next_nodes(current_node: LinearMapNodeData) -> void:
	for next_id in current_node.connected_to_ids:
		var next_node = all_nodes.get(next_id)
		if next_node and next_node.status == LinearMapNodeData.LocationStatus.NEXT_LOCKED:
			next_node.status = LinearMapNodeData.LocationStatus.AVAILABLE


func _repair_orphaned_nodes(columns_data: Array[Array]) -> void:
	# Iterate from the 2nd column to the last
	for col_idx in range(1, columns_data.size()):
		var current_col = columns_data[col_idx]
		var prev_col = columns_data[col_idx - 1]
		
		for node in current_col:
			if not _has_incoming_connection(node, prev_col):
				# Orphan detected! Force connection from closest parent.
				var best_parent = _find_closest_node(node, prev_col)
				if best_parent:
					best_parent.add_connection(node.id)


func _has_incoming_connection(target_node: LinearMapNodeData, prev_col_nodes: Array) -> bool:
	for parent in prev_col_nodes:
		if target_node.id in parent.connected_to_ids:
			return true
	return false


func _find_closest_node(ref_node: LinearMapNodeData, candidates_list: Array) -> LinearMapNodeData:
	if candidates_list.is_empty():
		return null
		
	var closest = candidates_list[0]
	var min_dist = 9999
	
	for candidate in candidates_list:
		var dist = abs(ref_node.grid_position.y - candidate.grid_position.y)
		if dist < min_dist:
			min_dist = dist
			closest = candidate
			
	return closest


func _mark_valid_future_nodes(start_node: LinearMapNodeData) -> void:
	for child_id in start_node.connected_to_ids:
		var child_node = all_nodes.get(child_id)
		if child_node:
			# If the node is currently UNREACHABLE, we found a valid path to it.
			# Mark it as LOCKED (valid future).
			if child_node.status == LinearMapNodeData.LocationStatus.UNREACHABLE:
				child_node.status = LinearMapNodeData.LocationStatus.LOCKED
				# Continue tracing forward
				_mark_valid_future_nodes(child_node)


func _set_initial_map_state(columns_data: Array[Array]) -> void:
	if columns_data.is_empty(): return
	if columns_data[0].is_empty(): return

	var start_node = columns_data[0][0]
	current_player_node_id = start_node.id
	
	# Initial Start: Current node is incomplete.
	# Logic will effectively treat this as a "Move" to the first node
	_broadcast_initial_player_position.call_deferred(start_node.id)
	_update_map_states_after_move(start_node)


func _broadcast_initial_player_position(node_id: String) -> void:
	player_moved.emit(node_id)
