@icon("uid://rp2et76mtf0e")
class_name GridHighlightManager
extends Node
## Manages visual highlighting of grid squares using TileMapLayers.
##
## This system allows stacking different highlight styles (e.g., movement range,
## attack range, cursor) on top of each other. It handles the logic of which
## style should be visible on a specific cell based on priority (insertion order).[br]
## [br]
## [b]Usage:[/b][br]
## 1. Add to the scene.[br]
## 2. Assign 'cursor_tile_layer' and 'highlight_tile_layer' in the Inspector.[br]
## 3. Populate 'highlight_styles' with GridHighlightStyle resources.[br]
## 4. Call add_highlights() to show a specific pattern.[br]
## 5. Call clear_highlights() to remove specific or all patterns.

# DEPENDENCIES
@export var cursor_tile_layer: TileMapLayer ## Layer used for the single-tile cursor.
@export var highlight_tile_layer: TileMapLayer ## Layer used for area highlights (movement, etc).

# CONFIGURATION
@export var highlight_styles: Array[GridHighlightStyle] = [] ## List of available highlight definitions.

# INTERNAL STATE
var _active_highlights: Dictionary = {} ## Key: style_name, Value: Array[Vector2i] (Grid Coords).
var _style_alt_ids: Dictionary = {} ## Key: style_name, Value: int (Alternative Tile ID generated at runtime).


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	add_to_group("grid_highlighter")
	_generate_runtime_tiles()


# PUBLIC METHODS

func add_highlights(style_name: String, world_positions: Array[Vector2], clear_previous: bool = false) -> void: ## Adds a set of highlights for a specific style.
	# Convert World to Grid Coords
	var new_cells: Array[Vector2i] = []
	for pos in world_positions:
		new_cells.append(highlight_tile_layer.local_to_map(pos))
	
	if clear_previous:
		if _active_highlights.has(style_name):
			_remove_visuals_for_style(style_name)
			_active_highlights[style_name] = []
	
	if not _active_highlights.has(style_name):
		_active_highlights[style_name] = []
		
	var list := _active_highlights[style_name] as Array
	list.append_array(new_cells)
	
	# Paint cells additively
	var style_resource := _get_style_by_name(style_name)
	if style_resource:
		for cell in new_cells:
			_paint_cell(cell, style_resource)


func clear_highlights(style_name: String = "") -> void: ## Clears a specific style or all highlights if name is empty.
	if style_name == "":
		_active_highlights.clear()
		highlight_tile_layer.clear()
	elif _active_highlights.has(style_name):
		_remove_visuals_for_style(style_name)
		_active_highlights.erase(style_name)


func set_tile_cursor(world_pos: Vector2, style: String) -> void: ## Moves the cursor highlight to the specific world position.
	var grid_pos := cursor_tile_layer.local_to_map(world_pos)
	var style_resource := _get_style_by_name(style)
	
	cursor_tile_layer.clear()
	
	if style_resource:
		cursor_tile_layer.set_cell(grid_pos, style_resource.source_id, style_resource.atlas_coords)
		# Apply the color modulation to the entire cursor layer
		cursor_tile_layer.modulate = style_resource.modulate_color
	else:
		# Reset to white if no style found (optional safety)
		cursor_tile_layer.modulate = Color.WHITE


func clear_tile_cursor() -> void:
	cursor_tile_layer.clear()

# PRIVATE METHODS

func _generate_runtime_tiles() -> void:
	# Ensure we have a valid TileSet to work with
	if not highlight_tile_layer.tile_set:
		push_error("GridHighlightManager: No TileSet assigned to highlight_tile_layer.")
		return
		
	var tile_set = highlight_tile_layer.tile_set
		
	for style in highlight_styles:
		
		if not style.is_cursor_style:
			# 1. Get the source (The Atlas)
			var source = tile_set.get_source(style.source_id) as TileSetAtlasSource
			if not source:
				push_warning("GridHighlightManager: Invalid source_id for style: %s" % style.style_name)
				continue
			
			# 2. Create a runtime alternative tile
			# create_alternative_tile returns the new integer ID for this specific variation
			var alt_id = source.create_alternative_tile(style.atlas_coords)
			
			# 3. Apply the color/alpha to this specific alternative
			var tile_data = source.get_tile_data(style.atlas_coords, alt_id)
			tile_data.modulate = style.modulate_color
			
			# 4. Store the ID mapped to the style name
			_style_alt_ids[style.style_name] = alt_id

#
#func _paint_cell(grid_pos: Vector2i, style: GridHighlightStyle) -> void:
	#highlight_tile_layer.set_cell(grid_pos, style.source_id, style.atlas_coords)


func _paint_cell(grid_pos: Vector2i, style: GridHighlightStyle) -> void:
	# Default to 0 (the original tile) if something went wrong
	var alt_id = 0
	
	if _style_alt_ids.has(style.style_name):
		alt_id = _style_alt_ids[style.style_name]
	
	# Pass the alt_id as the 4th argument
	highlight_tile_layer.set_cell(grid_pos, style.source_id, style.atlas_coords, alt_id)


func _remove_visuals_for_style(style_name: String) -> void:
	var cells_to_remove = _active_highlights[style_name]
	
	for cell in cells_to_remove:
		# Check if this cell is used by ANY other active style before clearing
		var replacement_style_name := _get_top_style_for_cell(cell, style_name)
		
		if replacement_style_name != "":
			var style := _get_style_by_name(replacement_style_name)
			_paint_cell(cell, style)
		else:
			highlight_tile_layer.set_cell(cell, -1)


func _get_top_style_for_cell(grid_pos: Vector2i, exclude_style: String) -> String:
	var keys := _active_highlights.keys()
	var found_style := ""
	
	# Determine "Z-Index" by insertion order in the dictionary
	for key in keys:
		if key == exclude_style: continue
		
		if grid_pos in _active_highlights[key]:
			found_style = key
			
	return found_style


func _get_style_by_name(name_to_find: String) -> GridHighlightStyle:
	for style in highlight_styles:
		if style.style_name == name_to_find:
			return style
	return null
