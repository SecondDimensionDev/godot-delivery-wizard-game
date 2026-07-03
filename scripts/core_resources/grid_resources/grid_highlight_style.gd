class_name GridHighlightStyle
extends Resource

## The name you will use in code (e.g., "move", "attack")
@export var style_name: String = ""

## The ID of the texture in your TileSet
@export var is_cursor_style: bool = false

## The ID of the texture in your TileSet
@export var source_id: int = 0

## The coordinates of the tile in the atlas
@export var atlas_coords: Vector2i = Vector2i(0, 0)

## Apply a color tint
@export var modulate_color: Color = Color.WHITE
