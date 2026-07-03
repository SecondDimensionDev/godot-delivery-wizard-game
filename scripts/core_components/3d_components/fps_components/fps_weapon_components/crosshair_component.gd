class_name CrosshairComponent
extends Control
## A customizable, procedural UI crosshair.
##
## Attach to a Control node (preferably centered via layout anchors).
## Uses Godot's 2D drawing API to render a crosshair without external textures.

# EXPORT VARIABLES
@export_group("Crosshair Settings")
@export var color: Color = Color.WHITE ## The color of the crosshair.
@export var line_length: float = 10.0 ## The length of each directional line.
@export var line_width: float = 2.0 ## The thickness of the lines.
@export var center_gap: float = 5.0 ## The empty space between the center and the lines.
@export var draw_center_dot: bool = false ## Whether to draw a dot in the exact center.
@export var auto_hide_on_pause: bool = true ## Automatically hide when the game is paused

@export var is_enabled: bool = true: ## Toggles visibility.
	set(value):
		is_enabled = value
		queue_redraw() # Forces the node to redraw when toggled

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Automatically centers the control node on the screen if parented to the CanvasLayer directly
	set_anchors_preset(Control.PRESET_CENTER)
	if auto_hide_on_pause:
		EventBus.system_state.game_paused.connect(hide_crosshair)
		EventBus.system_state.game_resumed.connect(show_crosshair)

func _draw() -> void:
	if not is_enabled:
		return

	# Calculate the center of this Control node
	var center := size / 2.0

	# 1. Draw Center Dot
	if draw_center_dot:
		draw_circle(center, line_width / 2.0, color)

	# 2. Draw Lines (Right, Left, Bottom, Top)
	draw_line(center + Vector2(center_gap, 0), center + Vector2(center_gap + line_length, 0), color, line_width)
	draw_line(center + Vector2(-center_gap, 0), center + Vector2(-center_gap - line_length, 0), color, line_width)
	draw_line(center + Vector2(0, center_gap), center + Vector2(0, center_gap + line_length), color, line_width)
	draw_line(center + Vector2(0, -center_gap), center + Vector2(0, -center_gap - line_length), color, line_width)

# PUBLIC FUNCTIONS
func set_color(new_color: Color) -> void: ## Allows other scripts to dynamically change the color (e.g., turning red over enemies).
	color = new_color
	queue_redraw()


func show_crosshair() ->void:
	is_enabled = true


func hide_crosshair() -> void:
	is_enabled = false
