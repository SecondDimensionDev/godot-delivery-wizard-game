@icon("uid://c1fbroi7xcr85")
class_name GridInteractive
extends Node

## Component that makes a Node2D interactable on the Grid.
##
## Registers with [GridInteractionManager] to receive click and hover events.[br]
## Add this to units, chests, or terrain to handle selection logic.

# SIGNALS
signal interacted ## Emitted when the user clicks this object witht eh primary mouse button.
signal interacted_alt ## Emmited when the user cliks on this object with the alt mouse button
signal hover_started ## Emitted when the mouse enters the object's grid cell.
signal hover_ended ## Emitted when the mouse leaves the object's grid cell.
signal other_cell_hovered(cell: Vector2i, world_pos: Vector2) ## Emmited when any other cell is hovered. Only when subscribed via start_listening_for_all_clicks()
signal other_empty_cell_clicked(cell: Vector2i,world_pos: Vector2, is_alt: bool) ## Emmited when any other empty cell is clicked. Only when subscribed via start_listening_for_all_clicks()
signal other_occupied_cell_clicked(cell: Vector2i,world_pos: Vector2, is_alt: bool) ## Emmited when any other occupied cell is clicked. Only when subscribed via start_listening_for_all_clicks()

# EXPORT VARIABLES

@export_group("Dependencies")
@export var parent_node: Node2D ## The visual root of the object (used for position).
@export var grid_shape: GridShape ## Optional: Defines the click area.

@export_group("Interaction")
@export var is_interactive: bool = true ## If false, ignores all inputs.
@export var is_hoverable: bool = true ## If false, does not check for mouse hover.
@export var priority: int = 0 ## Higher priority objects block clicks on lower ones.
@export var consume_input: bool = true ## If true, clicking this prevents clicking objects below it.
@export var consume_alt_input: bool = true ## If true, alt clicking this prevents alt clicking objects below it.

@export_group("Movement")
@export var update_location_when_moving: bool = false ## Update registry every frame whilst is_moving is true.

#PUBLIC VARIABLES

var is_moving: bool = false: ## Set this when the parent entity is moving so interactive grid position can be updated
	set(value):
		is_moving = value
		if not is_moving:
			update_interactive_grid_position()

# INTERNAL VARIABLES

var _manager: GridInteractionManager
var _last_occupied_cells: Array[Vector2i] = []
var _grid_manager_ref: GridMapManager # Cached for coordinate conversion


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	if not parent_node:
		parent_node = get_parent() as Node2D
		if not parent_node:
			push_error("GridInteractive: No Parent Node2D found.")
			return
			
	_locate_manager()
	_locate_grid_map()
	
	# Initial Registration
	if _manager and _grid_manager_ref:
		_register_at_current_position()


func _exit_tree() -> void:
	remove_from_interactive_grid()


func _process(_delta: float) -> void:
	# Safety Checks
	if not _manager or not _grid_manager_ref:
		return
	# Only run position checks if we are actually a moving unit and want to continuously update
	if not update_location_when_moving or not is_moving:
		return
	
	update_interactive_grid_position()


# PUBLIC FUNCTIONS

func on_interact(is_alt: bool = false) -> void: ## Called by the manager when clicked.
	if not is_interactive:
		return
	
	if is_alt:
		interacted_alt.emit()
	else:
		interacted.emit()


func on_hover_enter() -> void: ## Called by the manager when hovered.
	if is_hoverable:
		hover_started.emit()


func on_hover_exit() -> void: ## Called by the manager when un-hovered.
	if is_hoverable:
		hover_ended.emit()


func get_interactive_cells() -> Array[Vector2i]: ## Returns all cells this object currently occupies.
	return _last_occupied_cells


func update_interactive_grid_position() -> void: ## Update this component's position in the registry of interactive items on the grid
	var root_cell = _grid_manager_ref.base_tile_map.local_to_map(parent_node.global_position)
	var new_cells: Array[Vector2i] = []
	
	if grid_shape:
		new_cells = grid_shape.get_occupied_cells(root_cell)
	else:
		new_cells.append(root_cell)
		
	# Optimization: If the set of cells hasn't changed, do nothing
	if new_cells == _last_occupied_cells:
		return
	
	_manager.update_interactive_area(self, _last_occupied_cells, new_cells)
	_last_occupied_cells = new_cells


func remove_from_interactive_grid() -> void: ## Remove this component from the registry of interactive items on the grid
	if _manager:
		for cell in _last_occupied_cells:
			_manager.unregister_interactive(self, cell)
	_last_occupied_cells.clear()


func start_listening_for_any_hover() -> void: ## Subscribe to signals from the interaction manager about other cells being hovered
	if _manager:
		_manager.cell_hovered.connect(_other_cell_hovered)


func stop_listening_for_any_hover() -> void: ## Unubscribe to signals from the interaction manager about other cells being hovered
	if _manager:
		_manager.cell_hovered.disconnect(_other_cell_hovered)


func start_listening_for_all_clicks() -> void: ## Subscribe to signals from the interaction manager about other clicks
	if _manager:
		_manager.cell_clicked_empty.connect(_empty_cell_click)
		_manager.cell_clicked_occupied.connect(_other_occupied_cell_click)


func stop_listening_for_all_clicks() -> void: ## Unsubscribe from signals from the interaction manager about other clicks
	if _manager:
		_manager.cell_clicked_empty.disconnect(_empty_cell_click)
		_manager.cell_clicked_occupied.disconnect(_other_occupied_cell_click)


# PRIVATE FUNCTIONS

func _register_at_current_position() -> void:
	var root_cell = _grid_manager_ref.base_tile_map.local_to_map(parent_node.global_position)
	
	if grid_shape:
		_last_occupied_cells = grid_shape.get_occupied_cells(root_cell)
	else:
		_last_occupied_cells = [root_cell]
		
	for cell in _last_occupied_cells:
		_manager.register_interactive(self, cell)


func _empty_cell_click(cell: Vector2i, world_pos: Vector2, is_alt: bool) -> void:
	other_empty_cell_clicked.emit(cell, world_pos, is_alt)


func _other_occupied_cell_click(cell: Vector2i, world_pos: Vector2, is_alt: bool) -> void:
	if cell in _last_occupied_cells:
		return
	
	other_occupied_cell_clicked.emit(cell, world_pos, is_alt)


func _other_cell_hovered(cell: Vector2i, world_pos: Vector2) -> void:
	other_cell_hovered.emit(cell, world_pos)


func _locate_manager() -> void:
	var managers = get_tree().get_nodes_in_group("grid_interaction_manager")
	if managers.size() > 0:
		_manager = managers[0]
	else:
		push_warning("GridInteractive: GridInteractionManager not found in group.")


func _locate_grid_map() -> void:
	# We need the grid map solely for local_to_map conversions in _process
	var grids = get_tree().get_nodes_in_group("grid_map_manager")
	if grids.size() > 0:
		_grid_manager_ref = grids[0]
