@icon("uid://8hfdpbds5puj")
class_name GridInteractionManager
extends Node

## Central manager for handling input interactions on the Grid.
##
## This node listens for mouse input, translates screen coordinates to Grid Coordinates
## via the [GridMapManager], and dispatches events to registered [GridInteractive] components.[br]
## It handles stacking order (Priority) and "consuming" inputs so clicks don't fall through UI or Units.

# SIGNALS

signal cell_hovered(cell: Vector2i, world_pos: Vector2) ## Emitted when the mouse moves over a new grid cell.
signal cell_clicked_any(cell: Vector2i, world_pos: Vector2, is_alt: bool) ## Emitted globally when any valid grid cell is clicked.
signal cell_clicked_empty(cell: Vector2i, world_pos: Vector2, is_alt: bool) ## Fires ONLY if the cell has no interactables
signal cell_clicked_occupied(cell: Vector2i, world_pos: Vector2, is_alt: bool) ## Fires ONLY if the cell has interactables

# EXPORT VARIABLES

@export_group("Dependencies")
@export var grid_manager: GridMapManager ## Reference to the GridMapManager for coordinate conversion.

@export_group("Input Settings")
@export var mouse_input_button: MouseButton = MOUSE_BUTTON_LEFT ## Which button triggers an primary interaction.
@export var mouse_alt_input_button: MouseButton = MOUSE_BUTTON_RIGHT ## Which button triggers an alternative interaction.

# INTERNAL VARIABLES

var _registry: Dictionary = {} ## Spatial Hash: { Vector2i: Array[GridInteractive] }
var _last_hovered_cell: Vector2i = Vector2i(99999, 99999) ## Tracks the last cell to handle hover_exit.


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	add_to_group("grid_interaction_manager")
	if not grid_manager:
		_locate_grid_manager()


func _unhandled_input(event: InputEvent) -> void:
	if not grid_manager or not grid_manager.base_tile_map:
		return
	
	if event is InputEventMouse:
		var current_cell = grid_manager.base_tile_map.local_to_map(grid_manager.base_tile_map.get_global_mouse_position())
		
		var snapped_world_pos = grid_manager.base_tile_map.map_to_local(current_cell)
		
		# 1. Handle Hover Logic
		if current_cell != _last_hovered_cell:
			_process_hover_change(_last_hovered_cell, current_cell)
			_last_hovered_cell = current_cell
			
			cell_hovered.emit(current_cell, snapped_world_pos)
		
		if event is InputEventMouseButton and event.pressed:
			# 2. Handle Primary Click Logic
			if event.button_index == mouse_input_button:
				_process_click(current_cell, snapped_world_pos, false)
				cell_clicked_any.emit(current_cell, snapped_world_pos, false)
				
			# 3. Handle Alternative Click Logic
			elif event.button_index == mouse_alt_input_button:
				_process_click(current_cell, snapped_world_pos, true)
				cell_clicked_any.emit(current_cell, snapped_world_pos, true)
			
			#get_viewport().set_input_as_handled()

# PUBLIC FUNCTIONS

func register_interactive(component: GridInteractive, grid_pos: Vector2i) -> void: ## Registers a component at a specific cell.
	if not _registry.has(grid_pos):
		_registry[grid_pos] = []
	
	if component not in _registry[grid_pos]:
		_registry[grid_pos].append(component)
		_sort_cell_interactables(grid_pos)


func unregister_interactive(component: GridInteractive, grid_pos: Vector2i) -> void: ## Removes a component from a specific cell.
	if _registry.has(grid_pos):
		_registry[grid_pos].erase(component)
		if _registry[grid_pos].is_empty():
			_registry.erase(grid_pos)


func update_interactive_area(component: GridInteractive, old_cells: Array[Vector2i], new_cells: Array[Vector2i]) -> void: ## Atomic move operation for multi-tile entities.
	# 1. Remove from all old cells
	for cell in old_cells:
		unregister_interactive(component, cell)
	
	# 2. Add to all new cells
	for cell in new_cells:
		register_interactive(component, cell)


func is_cell_occupied(cell: Vector2i) -> bool: ## Returns true if any active interactables are registered on this cell.
	if not _registry.has(cell):
		return false
	return not _registry[cell].is_empty()


func has_interactive_at(cell: Vector2i, component: GridInteractive) -> bool: ## Returns true if the specific component is registered at the specific cell.
	if not _registry.has(cell):
		return false
	return component in _registry[cell]


func get_interactables_at(cell: Vector2i) -> Array[GridInteractive]: ## Returns a list of all components at this cell (or an empty array).
	if _registry.has(cell):
		return _registry[cell]
	return []


# PRIVATE FUNCTIONS

func _locate_grid_manager() -> void:
	var managers = get_tree().get_nodes_in_group("grid_map_manager")
	if managers.size() > 0:
		grid_manager = managers[0]
	else:
		push_warning("GridInteractionManager: No GridMapManager found in group 'grid_map_manager'")


func _process_click(cell: Vector2i, world_pos: Vector2, is_alt: bool = false) -> void:
	if not _registry.has(cell) or _registry[cell].is_empty():
		cell_clicked_empty.emit(cell, world_pos, is_alt)
		return
	
	cell_clicked_occupied.emit(cell, world_pos, is_alt)
	var interactables: Array = _registry[cell]
	
	# Iterate through components (Already sorted by priority)
	for item in interactables:
		if item is GridInteractive:
			item.on_interact(is_alt)
			
			# If this item consumes input (e.g. a Unit), don't click the floor beneath it
			if item.consume_input and not is_alt:
				break
			if item.consume_alt_input and is_alt:
				break


func _process_hover_change(old_cell: Vector2i, new_cell: Vector2i) -> void:
	# 1. Exit old cell
	if _registry.has(old_cell):
		for item in _registry[old_cell]:
			if item:
				item.on_hover_exit()
	
	# 2. Enter new cell
	if _registry.has(new_cell):
		for item in _registry[new_cell]:
			if item:
				item.on_hover_enter()


func _sort_cell_interactables(cell: Vector2i) -> void:
	# Sort descending (Higher priority first)
	var list = _registry[cell]
	list.sort_custom(func(a, b): return a.priority > b.priority)
