@icon("uid://tismft72c7to")
class_name InterfaceList
extends ScrollContainer

# --- Configuration ---
@export_group("Setup")
@export var item_scene: PackedScene	
@export var id_key: String = "id" # The unique key in your DB data (e.g., "user_id")

@export_group("Layout")
@export_enum("Vertical List", "Grid") var list_layout_mode: int = 0
@export_enum("Start", "Center", "End") var alignment: int = 0
@export var item_spacing: Vector2 = Vector2(5, 5)
@export var list_margins: int = 10
@export var grid_columns: int = 3 # Only used if Layout Mode is Grid
@export var expand_items_width: bool = true

@export_group("Behavior")
@export_enum("None", "Single", "Single Toggle", "Multi", "Multi CTRL") var selection_mode: int = 1
@export var select_hidden_items: bool = false
@export_enum("No Action","Custom Action","Move Selection") var primary_action = 0
@export_enum("No Action","Custom Action","Move Selection") var secondary_action = 0
@export var sort_mode: SortMode = SortMode.NO_SORTING: ## How should the list be sorted. Automatically enables and disables Drag&Drop
	set(new_value):
		sort_mode = new_value
		if sort_mode == SortMode.DRAG_AND_DROP:
			set_drag_enabled(true)
		else:
			set_drag_enabled(false)


# --- Signals ---
signal selection_changed(selected_items: Array[Dictionary])
signal item_action_requested(item_data: Dictionary)
signal item_move_requested(item_data: Dictionary)
signal item_selected(item_data: Dictionary)

# --- Internal Variables ---
var _master_data: Array[Dictionary] = [] # The full database
var _display_data: Array[Dictionary] = [] # The filtered list
var _selected_ids: Array = [] # Stores IDs of selected items
var filter_criteria: Dictionary = {}
var is_active: bool = true
var enable_drag_and_drop: bool = false

# Internal Nodes
var _margin_container: MarginContainer
var _content_container: Container

#Enums
enum SortMode {NO_SORTING, ASCENDING, DESCENDING, DRAG_AND_DROP}


# SETUP & CORE STATE
func _ready() -> void:
	_setup_containers()
	initial_data_load()
	sort_mode = sort_mode


func _setup_containers() -> void:
	# Clear existing if any (useful if re-running setup)
	for child in get_children():
		child.queue_free()
	
	# Create MarginContainer for edge padding
	_margin_container = MarginContainer.new()
	# Set margins based on export
	_margin_container.add_theme_constant_override("margin_top", list_margins)
	_margin_container.add_theme_constant_override("margin_left", list_margins)
	_margin_container.add_theme_constant_override("margin_bottom", list_margins)
	_margin_container.add_theme_constant_override("margin_right", list_margins)
	
	# Make margins expand to fill the ScrollContainer
	_margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	add_child(_margin_container)
	
	# Create the actual layout container
	if list_layout_mode == 0: # Vertical List
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(item_spacing.y))
		_content_container = vbox
	else: # Grid
		var grid = GridContainer.new()
		grid.columns = grid_columns
		grid.add_theme_constant_override("h_separation", int(item_spacing.x))
		grid.add_theme_constant_override("v_separation", int(item_spacing.y))
		_content_container = grid

# Apply Alignment
	if _content_container is BoxContainer:
		# BoxContainers use the alignment property to pack children
		_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match alignment:
			0: _content_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			1: _content_container.alignment = BoxContainer.ALIGNMENT_CENTER
			2: _content_container.alignment = BoxContainer.ALIGNMENT_END
			
	elif _content_container is GridContainer:
		# GridContainers do not have an alignment property.
		# To align a Grid, we manipulate its size flags to position the whole grid
		# within the parent MarginContainer.
		match alignment:
			0: # Start (Left)
				_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			1: # Center
				_content_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			2: # End (Right)
				_content_container.size_flags_horizontal = Control.SIZE_SHRINK_END

	# Ensure vertical expansion is always active so scrolling works
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_margin_container.add_child(_content_container)


func set_active(active: bool) -> void:
	is_active = active
	
	# Iterate through all existing items and update their state
	for child in _content_container.get_children():
		if child is InterfaceListItem:
			# If list is active, item is NOT disabled.
			# If list is inactive, item IS disabled.
			child.set_disabled(not is_active)


# DATA MANAGEMENT
func set_data(new_data_array: Array[Dictionary], keep_filters: bool, keep_selection: bool) -> void:
	_master_data = new_data_array.duplicate(true)
	
	if not keep_filters:
		filter_criteria = {}
	if not keep_selection:
		_selected_ids.clear()
	if keep_selection:
		_validate_selected_items_exist()
	
	refresh_display_data()


func initial_data_load() -> void:
	# Virtual function, override when extending
	pass


func add_item(item_data: Dictionary) -> void:
	_master_data.append(item_data)
	if _is_item_visible(item_data): # Check filter before adding to display
		_display_data.append(item_data)
		_refresh_view()


func remove_item_by_id(target_id: Variant) -> void:
	_master_data = _master_data.filter(func(x): return x.get(id_key) != target_id)
	_display_data = _display_data.filter(func(x): return x.get(id_key) != target_id)
	
	if target_id in _selected_ids:
		_selected_ids.erase(target_id)
		_emit_selection()
		
	_refresh_view()


func cleardown_list() -> void:
	set_data([], false, false) 


func reset_list() -> void:
	cleardown_list()
	initial_data_load()
	set_active(true)


# DATA RETRIEVAL
func get_all_selected_items() -> Array[Dictionary]:
	# Returns the full dictionary objects of selected items
	return _master_data.filter(func(item): return item.get(id_key) in _selected_ids)


func get_selected_item() -> Dictionary:
	var items = get_all_selected_items()

	if items.size() > 0:
		return items.back()
	else:
		return {}


# Returns an array of values for a specific key from the data
# key: The dictionary key to look for (e.g., "item_name")
# use_filtered_data: If true, returns values only from visible items. If false, checks the whole database.
func get_values_by_key(key: String, use_filtered_data: bool = false) -> Array:
	var source_array = _display_data if use_filtered_data else _master_data
	var result_array = []
	
	for item in source_array:
		# Safety check: only add if the key actually exists in this item
		if item.has(key):
			result_array.append(item[key])
			
	return result_array


# FILTERING
func update_all_filters(new_criteria: Dictionary) -> void:
	filter_criteria = new_criteria
	refresh_display_data()


func clear_all_filters() -> void:
	filter_criteria = {}
	refresh_display_data()


# 1. Sets/Overwrites a specific key with an array of criteria
# Example: set_filter_category("rarity", ["Epic", "Legendary"])
func set_filter_category(key: String, values: Array) -> void:
	filter_criteria[key] = values
	refresh_display_data()


# 2. Removes a category key entirely
# Example: remove_filter_category("rarity") -> stops filtering by rarity
func remove_filter_category(key: String) -> void:
	if filter_criteria.has(key):
		filter_criteria.erase(key)
		refresh_display_data()


# 3. Adds a single value to a specific key (OR logic within that key)
# Example: add_filter_value("type", "Sword")
func add_filter_value(key: String, value: Variant) -> void:
	# If the key doesn't exist yet, start a new array
	if not filter_criteria.has(key):
		filter_criteria[key] = []
	
	# Only add if it's not already there to prevent duplicates
	if not value in filter_criteria[key]:
		filter_criteria[key].append(value)
		refresh_display_data()


# 4. Removes a single value from a specific key
# Example: remove_filter_value("type", "Axe")
func remove_filter_value(key: String, value: Variant) -> void:
	if filter_criteria.has(key):
		filter_criteria[key].erase(value)
		
		if filter_criteria[key].is_empty():
			filter_criteria.erase(key)
			
		refresh_display_data()


# SORTING
func apply_default_sort() -> void:
	if sort_mode == SortMode.ASCENDING:
		# Sorts in Ascending order (A to Z, or 0 to 9) based on the ID
		_display_data.sort_custom(func(a, b): 
			return a.get(id_key) < b.get(id_key)
		)
		
	if sort_mode == SortMode.DESCENDING:
		# Sorts in Descending order (A to Z, or 0 to 9) based on the ID
		_display_data.sort_custom(func(a, b): 
			return a.get(id_key) > b.get(id_key)
		)


# VALIDATION
func _is_item_visible(item_data: Dictionary) -> bool:
	if filter_criteria.is_empty():
		return true
		
	for key in filter_criteria:
		var allowed_values = filter_criteria[key]
		
		# If the filter array is empty, we assume it means "allow all" for this key
		# or you can choose "allow none". usually "allow all" is safer.
		if allowed_values.is_empty():
			continue
			
		# If the item doesn't have the key, we hide it (strict filtering)
		if not item_data.has(key):
			return false
			
		# The standard logic: Value must be IN the allowed list
		if not item_data[key] in allowed_values:
			return false
			
	return true


func _validate_selection_after_filter() -> void:
	# 1. Identify which selected IDs are no longer visible
	var ids_to_remove = []
	
	for selected_id in _selected_ids:
		var is_still_visible = false
		for item in _display_data:
			if item.get(id_key) == selected_id:
				is_still_visible = true
				break
		
		if not is_still_visible:
			var remove_item: bool = false
			
			if not select_hidden_items or selection_mode ==1:
				remove_item = true
			
			if remove_item:
				ids_to_remove.append(selected_id)
	
	# 2. Remove invalid selections
	for id in ids_to_remove:
		_selected_ids.erase(id)
	
	# 3. Handle "Single Select" auto-selection behavior
	# If we are in Single Mode (1) and lost our selection, pick the first one.
	if selection_mode == 1 and _selected_ids.is_empty():
		if not _display_data.is_empty():
			var first_item = _display_data[0]
			var first_id = first_item.get(id_key)
			_selected_ids.append(first_id)
			
	# 4. Notify listeners that the selection effectively changed
	# (Only if we actually changed something to avoid spamming signals)
	if not ids_to_remove.is_empty() or (selection_mode == 1 and not _selected_ids.is_empty()):
		_emit_selection()


func _validate_selected_items_exist() -> void:
	# 1. Collect all valid IDs currently in the master database
	var valid_master_ids = []
	for item in _master_data:
		valid_master_ids.append(item.get(id_key))
	
	# 2. Check current selections against valid IDs
	# We iterate backwards so we can safely remove items while looping
	for i in range(_selected_ids.size() - 1, -1, -1):
		var selected_id = _selected_ids[i]
		
		if not selected_id in valid_master_ids:
			# The selected item no longer exists in the database
			_selected_ids.remove_at(i)


func refresh_display_data() -> void:
	_display_data.clear()
	
	# 1. Rebuild the filtered list
	for item in _master_data:
		if _is_item_visible(item):
			_display_data.append(item)
	

	# 2. Validate the selection (Auto-select first if needed)
	_validate_selection_after_filter()
	
	# 3. Sort
	apply_default_sort()
	
	# 4. Redraw the UI
	_refresh_view()


# RENDERING
func _refresh_view() -> void:
	if not _content_container: return
	
	# Clear current children
	for child in _content_container.get_children():
		child.queue_free()
		
	if not item_scene:
		push_warning("InterfaceList: No Item Scene assigned.")
		return

	for index in _display_data.size():
		var data_item = _display_data[index]
		var instance = item_scene.instantiate() as InterfaceListItem
		
		if not instance:
			push_error("InterfaceList: Item scene must inherit from InterfaceListItem")
			continue
			
		_content_container.add_child(instance)
		
		# Layout settings
		if expand_items_width:
			instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Setup data
		instance.setup(data_item, index)
		
		# Check selection state
		var item_id = data_item.get(id_key)
		instance.set_selected(item_id in _selected_ids)
		
		# Sync active state
		instance.set_disabled(not is_active)
		instance.drag_enabled = enable_drag_and_drop
		
		# Connect signals
		instance.request_selection.connect(_on_item_selection_requested)
		instance.request_primary_action.connect(_on_item_primary_action_requested)
		instance.request_secondary_action.connect(_on_item_secondary_action_requested)
		instance.request_move_item.connect(_on_item_move_requested)



# SELECTION FUNCTIONS
func deselect_all() -> void:
	_selected_ids.clear()
	_update_selection_visuals()
	_emit_selection()


func select_first_item() -> void:
	if _display_data.is_empty():
		return
		
	if selection_mode == 0: # None
		return

	# Get the ID of the very first item currently visible
	var first_item = _display_data[0]
	var first_id = first_item.get(id_key)
	
	# Force the selection to this item only
	_selected_ids.clear()
	_selected_ids.append(first_id)
	
	# Update visuals and notify the rest of the game
	_update_selection_visuals()
	_emit_selection()



# INTERACTION LOGIC
func _on_item_selection_requested(item_node: InterfaceListItem, is_multi: bool) -> void:
	if selection_mode == 0: return # None
	
	var item_id = item_node.data.get(id_key)
	
	if selection_mode == 1: # Single Select
		if item_id not in _selected_ids:
			_selected_ids.clear()
			_selected_ids.append(item_id)
		
	if selection_mode == 2: # Single Select Toggle
		if item_id in _selected_ids:
			_selected_ids.clear()
		else:
			_selected_ids.clear()
			_selected_ids.append(item_id)
		
	elif selection_mode == 3: # Multi Select
		if item_id in _selected_ids:
			_selected_ids.erase(item_id)
		else:
			_selected_ids.append(item_id)
			
	elif selection_mode == 4: # Multi Select with CTRL
		if is_multi:
			# Toggle specific item while keeping others
			if item_id in _selected_ids:
				_selected_ids.erase(item_id)
			else:
				_selected_ids.append(item_id)
		else:
			# Reset selection to just this one
			_selected_ids.clear()
			_selected_ids.append(item_id)

	# Update Visuals
	_update_selection_visuals()
	_emit_selection()


func _on_item_primary_action_requested(item_node: InterfaceListItem) -> void:
	if primary_action == 0:
		return
	
	if primary_action == 1:
		item_action_requested.emit(item_node.data)
	
	if primary_action == 2:
		item_move_requested.emit(item_node.data)


func _on_item_secondary_action_requested(item_node: InterfaceListItem) -> void:
	if secondary_action == 0:
		return
	
	if secondary_action == 1:
		item_action_requested.emit(item_node.data)
	
	if secondary_action == 2:
		item_move_requested.emit(item_node.data)


func _update_selection_visuals() -> void:
	for child in _content_container.get_children():
		if child is InterfaceListItem:
			var i_id = child.data.get(id_key)
			child.set_selected(i_id in _selected_ids)


func _emit_selection() -> void:
	var items = get_all_selected_items()
	
	# 1. Emit the standard array signal
	selection_changed.emit(items)
	
	# 2. Emit the convenient single-item signal
	if items.size() > 0:
		# We emit the last item in the list (usually the most recently clicked)
		item_selected.emit(items.back())
	else:
		# Emit an empty dictionary to tell listeners to "clear" their view
		item_selected.emit({})


func _on_item_move_requested(source_item: InterfaceListItem, target_item: InterfaceListItem) -> void:
	# We rearrange the _master_data so the change is permanent
	var source_data = source_item.data
	var target_data = target_item.data
	
	var from_index = _master_data.find(source_data)
	var to_index = _master_data.find(target_data)
	
	if from_index == -1 or to_index == -1:
		return # Safety check
	
	# 1. Remove source from old position
	var item_to_move = _master_data.pop_at(from_index)
	
	# 2. Recalculate target index 
	# (If we removed an item from *before* the target, the target's index has shifted down by 1)
	to_index = _master_data.find(target_data)
	
	# 3. Insert at new position
	_master_data.insert(to_index, item_to_move)
	
	# 4. Refresh view
	# IMPORTANT: Ensure _apply_default_sort() is DISABLED in _refresh_display_data() 
	# or this visual change will be instantly overwritten.
	refresh_display_data()


func set_drag_enabled(enabled: bool) -> void:
	enable_drag_and_drop = enabled
	if _content_container:
		# Update all existing items immediately
		for child in _content_container.get_children():
			if child is InterfaceListItem:
				child.drag_enabled = enabled
