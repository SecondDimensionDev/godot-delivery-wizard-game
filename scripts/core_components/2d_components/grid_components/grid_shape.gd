@tool
@icon("uid://msyotmrsi37m")
class_name GridShape
extends Node2D

## Defines the grid footprint of an entity.
##
## Used by GridBlocker (collisions) and GridInteractive (clicks).
## Can be set to a simple rectangle or a custom list of tile offsets.

enum ShapeType { RECTANGLE, CUSTOM }

@export_group("Shape Settings")
@export var shape_type: ShapeType = ShapeType.RECTANGLE:
	set(value):
		shape_type = value
		queue_redraw()

@export var size: Vector2i = Vector2i(1, 1): ## Dimensions for Rectangle mode
	set(value):
		size = value
		queue_redraw()

@export var custom_offsets: Array[Vector2i] = [Vector2i(0,0)]: ## Specific tiles for Custom mode (relative to root)
	set(value):
		custom_offsets = value
		queue_redraw()


@export_group("Debug Visuals")
@export var debug_color: Color = Color(0.0, 1.0, 0.2, 0.4):
	set(value):
		debug_color = value
		queue_redraw()

@export var debug_tile_size: Vector2i = Vector2i(32, 32): ## Visual scale for editor preview
	set(value):
		debug_tile_size = value
		queue_redraw()


# PUBLIC FUNCTIONS

func get_occupied_cells(root_grid_pos: Vector2i) -> Array[Vector2i]: ## Returns the GLOBAL grid coordinates occupied by this shape.
	var final_cells: Array[Vector2i] = []
	var offsets = _get_shape_offsets()
	
	for offset in offsets:
		final_cells.append(root_grid_pos + offset)
		
	return final_cells


# PRIVATE FUNCTIONS

func _get_shape_offsets() -> Array[Vector2i]:
	if shape_type == ShapeType.RECTANGLE:
		var offsets: Array[Vector2i] = []
		for x in range(size.x):
			for y in range(size.y):
				offsets.append(Vector2i(x, y))
		return offsets
	else:
		return custom_offsets


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
		
	var offsets = _get_shape_offsets()
	for offset in offsets:
		var draw_pos = Vector2(offset) * Vector2(debug_tile_size)
		var rect = Rect2(draw_pos, Vector2(debug_tile_size))
		
		draw_rect(rect, debug_color)
		draw_rect(rect, debug_color.lightened(0.2), false, 2.0)
