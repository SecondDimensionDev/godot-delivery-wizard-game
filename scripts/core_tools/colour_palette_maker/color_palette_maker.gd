@tool
extends Resource
class_name ColourPaletteMaker

enum SortMethod { NONE, HUE, SATURATION, VALUE, BRIGHTNESS }

@export_group("Setup Palette")
@export_file("*.hex", "*.txt") var source_file_path: String
@export var add_black_and_white: bool = false
@export var sort_source_palette: SortMethod = SortMethod.NONE
@export var remove_duplicates_on_import: bool = false
@export var palette_preview: Texture2D
@export_tool_button("Preview Palette", "ConfirmationDialog")
var preview_action: Callable = _preview_palette

@export_group("Generate Palette")
@export_dir var palette_output_folder: String = "res://"
@export_tool_button("Generate Palette", "Bucket")
var generate_action: Callable = _generate_palette

@export_group("Export Palette")
@export var palette_to_export: ColorPalette 
@export_dir var file_export_folder: String = "res://"
@export var export_alpha_values: bool = false
@export var sort_exported_palette: SortMethod = SortMethod.NONE
@export var remove_duplicates_on_export: bool = false
@export_tool_button("Export Palette", "AssetLib")
var export_action: Callable = _export_resource_to_hex


func _preview_palette() -> void:
	_extract_palette_from_file()


func _generate_palette() -> void:
	var extracted_colours = _extract_palette_from_file()
	if not extracted_colours.is_empty():
		_save_palette_resource(extracted_colours)


func _extract_palette_from_file() -> Array:
	if source_file_path.is_empty():
		push_error("[Palette Maker] No Source Palette File Found")
		return []
	
	if not FileAccess.file_exists(source_file_path):
		push_error("[Palette Maker] Source Palette File does not exist at filepath")
		return []
	
	var file = FileAccess.open(source_file_path, FileAccess.READ)
	if file == null:
		push_error("[Palette Maker] Failed to open Source Palette File. Error: ", FileAccess.get_open_error())
		return []

	var extracted_colours: Array[Color] = []
	
	if add_black_and_white:
		extracted_colours.append(Color.from_string("000000", "000000"))
		extracted_colours.append(Color.from_string("FFFFFF", "FFFFFF"))
	
	while file.get_position() < file.get_length(): # Parse each line
		var line = file.get_line().strip_edges()
		
		if line.is_empty():
			continue # Skip empty lines
			
		# Create colour from string (Should handle #FF0000 or FF0000)
		var colour = Color.from_string(line, Color.MAGENTA)
		
		# Check if parsing failed (Color.from_string returns a default on failure)
		if colour == Color.MAGENTA and line.to_lower() != "ff00ff" and line.to_lower() != "#ff00ff":
			print_rich("[Palette Maker] Could not parse line '" + line + "' as colour")
			continue
			
		extracted_colours.append(colour)
		
	print("[Palette Maker] Extracted %d colours from source file" % [extracted_colours.size()])
	

	
	if remove_duplicates_on_import:
		extracted_colours = _apply_deduplicate(extracted_colours)
	
	extracted_colours = _apply_sort(extracted_colours, sort_source_palette)
		
	_generate_preview_texture(extracted_colours)
	return extracted_colours


func _save_palette_resource(colours: Array[Color]) -> void:
	# Create the new instance
	var new_palette = ColorPalette.new()
	new_palette.colors = colours
	
	var raw_name = source_file_path.get_file().get_basename()
	var clean_name = raw_name.to_snake_case().replace("-", "_").replace("__", "_")
	var corrected_name = clean_name.replace("_palette", "")
	var file_name = corrected_name + "_palette"
	var save_path = palette_output_folder.path_join(file_name + ".tres")
	
	# Save to disk
	var error = ResourceSaver.save(new_palette, save_path)
	
	if error == OK:
		print("[Palette Maker] Created %s palette with %d colors" % [clean_name, colours.size()])
		print("[Palette Maker] Saved ColorPalette resource at: %s" % [save_path])
		
		if Engine.is_editor_hint(): # Refresh Editor FileSystem
			var editor_interface = EditorInterface.get_resource_filesystem()
			editor_interface.scan() 
	else:
		push_error("[Palette Maker] Failed to generate colour palette resource. Error code: ", error)


func _generate_preview_texture(colours: Array[Color]) -> void:
	if colours.is_empty():
		palette_preview = null 
		emit_changed()
		return
	
	# Grid Size
	var swatch_size := 24
	var max_width := 256
	var columns = floori(max_width / float(swatch_size))
	var rows = ceil(float(colours.size()) / columns)
	
	# Preivew Texture Size
	var texture_width = columns * swatch_size
	var texture_height = int(rows * swatch_size)
	
	# Create blank preview image with the calculated height
	var image = Image.create(texture_width, texture_height, false, Image.FORMAT_RGBA8)
	
	var color_count = colours.size()
	
	for i in range(color_count):
		# Calculate Grid Position
		var col_idx = i % columns
		var row_idx = floori(i / float(columns))
		
		var x = col_idx * swatch_size
		var y = row_idx * swatch_size
		
		# Draw the colour swatch
		var rect = Rect2i(x, y, swatch_size, swatch_size)
		image.fill_rect(rect, colours[i])

	var image_texture = ImageTexture.create_from_image(image)
	
	palette_preview = image_texture 
	emit_changed() 
	
	print("[Palette Maker] Generated palette preview")


func _export_resource_to_hex() -> void:
	if palette_to_export == null:
			push_error("[Palette Maker] No Palette Resource selected")
			return
		
	if palette_to_export.colors.is_empty():
		push_error("[Palette Maker] The selected palette contains no colours")
		return
	
	var colours_to_write = palette_to_export.colors
	
	if remove_duplicates_on_export:
		colours_to_write = _apply_deduplicate(colours_to_write)
	
	if sort_exported_palette != SortMethod.NONE:
		colours_to_write = _apply_sort(colours_to_write, sort_exported_palette)
	
	# Use the ColorPalette resource name, with a fallback of "exported_palette"
	var file_name = "exported_palette"
	if not palette_to_export.resource_path.is_empty():
		file_name = palette_to_export.resource_path.get_file().get_basename()
	
	var save_path = file_export_folder.path_join(file_name + ".hex")
	
	var file = FileAccess.open(save_path, FileAccess.WRITE) # Open File for Writing
	if file == null:
		push_error("[Palette Maker] Could not create file at ", save_path)
		return
	
	# Write colour values to file
	for colour in colours_to_write:
		# to_html(false) excludes Alpha, to_html(false) includes Alpha
		var hex_string = "#" + colour.to_html(export_alpha_values)
		file.store_line(hex_string)
		
	file.close() # Godot should do this, but just in case
	
	print("[Palette Maker] Exported palette file to %s" % save_path)
	
	# Refresh Editor
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _apply_sort(colors: Array[Color], sort_method: SortMethod) -> Array[Color]:
	# If set to NONE, return immediately
	if sort_method == SortMethod.NONE:
		return colors
		
	# We duplicate the array so we don't mess up the original reference unintentionally
	var sorted_list = colors.duplicate()
	
	match sort_method:
		SortMethod.HUE:
			# Sort by Hue (Rainbow order)
			sorted_list.sort_custom(func(a, b): return a.h < b.h)
			
		SortMethod.SATURATION:
			# Sort by Saturation (Grey to Color)
			sorted_list.sort_custom(func(a, b): return a.s < b.s)
			
		SortMethod.VALUE:
			# Sort by Value (Dark to Light)
			sorted_list.sort_custom(func(a, b): return a.v < b.v)
			
		SortMethod.BRIGHTNESS:
			# Sort by Perceived Brightness (Luminance)
			sorted_list.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	
	print("[Palette Maker] Sorted %d colors by %s" % [colors.size(), SortMethod.keys()[sort_method]])
	return sorted_list


func _apply_deduplicate(colours: Array[Color]) -> Array[Color]:
	var unique: Array[Color] = []
	var seen_count = 0
	
	for c in colours:
		if not unique.has(c):
			unique.append(c)
		else:
			seen_count += 1
			
	if seen_count > 0:
		print("[Palette Maker] Removed %d duplicate colours" % seen_count)
	else:
		print("[Palette Maker] No duplicates colours found")
		
	return unique
