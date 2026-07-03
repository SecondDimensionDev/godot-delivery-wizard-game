@icon("uid://bkntydvjqurb4")
class_name HitPointModifierUIBar
extends Control

## A UI control that visualizes a specific Hit Point Modifier value.
##
## This node acts as a listener. It waits for the HitPointComponent to broadcast
## a change regarding a specific modifier_name (e.g., "Shield").
## It reuses the rendering logic from HitPointUIBar for consistency.

# EXPORT VARIABLES
@export_group("Configuration")
@export var hit_point_component: HitPointComponent ## The component data source.
@export var modifier_name: String = "" ## The name of the modifier to visualize.
@export var max_value: float = 100.0 ## The value considered "100%" for the bar width.
@export var hide_if_zero: bool = true ## If true, the bar hides itself when value is 0.

@export_group("Smooth Transition")
@export var smooth_transition: bool = true ## Transition smoothly between values or update instantly.
@export var transition_duration: float = 0.2 ## Duration of the smooth transition.

@export_group("Colours")
@export var bar_colour: Color = Color(0.2, 0.6, 0.9) ## The fill color of the bar.
@export var background_colour: Color = Color(0.2, 0.2, 0.2) ## Color of the empty background.

@export_group("Border & Shape")
@export var round_bar_edges: bool = true ## Toggles rounded corners.
@export var corner_radius: int = 5 ## How much to round the corners by.
@export var anti_alias_corners: bool = true ## Should rounded corners be anti-aliased
@export var draw_border: bool = true ## Toggles a border rect around the bar.
@export var border_colour: Color = Color(0.061, 0.061, 0.061, 1.0) ## Border line color.
@export var border_thickness: int = 2 ## Border line width.

# PRIVATE VARIABLES
var _current_target_value: float = 0.0 # The actual value reported by the modifier
var _visual_value: float = 0.0 # The interpolated value used for drawing
var _tween: Tween # Tween used to handle smooth transitions

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_initial_setup.call_deferred()


func _draw() -> void:
	var size_x = size.x
	var size_y = size.y
	
	# --- 1. Geometry ---
	var full_rect = Rect2(0, 0, size_x, size_y)
	var radius = corner_radius if round_bar_edges else 0
	var container_poly = _get_rounded_rect_poly(full_rect, radius)
	
	# --- 2. Calculate Fill using _visual_value ---
	var fill_ratio = clampf(_visual_value / max_value, 0.0, 1.0)
	var fill_width = size_x * fill_ratio
	
	# --- 3. Draw Background ---
	if fill_ratio < 1.0:
		draw_colored_polygon(container_poly, background_colour)
	
	# --- 4. Draw Bar (Clipped) ---
	if fill_ratio > 0.0:
		var slice_poly = PackedVector2Array([
			Vector2(0, 0),
			Vector2(fill_width, 0),
			Vector2(fill_width, size_y),
			Vector2(0, size_y)
		])
		
		var clipped_polys = Geometry2D.intersect_polygons(container_poly, slice_poly)
		for poly in clipped_polys:
			draw_colored_polygon(poly, bar_colour)
			
	# --- 5. Draw Border ---
	if draw_border:
		_draw_styled_box(full_rect, Color.TRANSPARENT, true, true, true)

# PRIVATE FUNCTIONS
func _on_modifier_changed(target_name: String, new_value: float) -> void:
	if target_name != modifier_name:
		return
		
	_current_target_value = new_value
	
	if _current_target_value > 0:
		visible = true
		
	# If smooth transition is disabled, update instantly
	if not smooth_transition:
		_visual_value = _current_target_value
		queue_redraw()
		if hide_if_zero and _current_target_value <= 0:
			visible = false
		return

	# Handle Smooth Transition using a Tween
	if _tween:
		_tween.kill() # Stop previous animation
		
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Tween the visual value to the target
	_tween.tween_property(self, "_visual_value", _current_target_value, transition_duration)
	
	# Force Redraw every frame during the tween
	_tween.tween_method(func(_dummy): queue_redraw(), 0.0, 1.0, transition_duration)
	
	# Chain a callback: If the target value is <= 0, hide when animation finishes
	if hide_if_zero and _current_target_value <= 0:
		_tween.chain().tween_callback(func(): visible = false)


func _draw_styled_box(rect: Rect2, colour: Color, round_left: bool, round_right: bool, is_border: bool) -> void: 
	var style = StyleBoxFlat.new()
	style.bg_color = colour
	
	if is_border:
		style.bg_color = Color.TRANSPARENT
		style.border_width_left = border_thickness
		style.border_width_top = border_thickness
		style.border_width_right = border_thickness
		style.border_width_bottom = border_thickness
		style.border_color = border_colour
		style.draw_center = false
	else:
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.border_color = Color.TRANSPARENT
		style.draw_center = true
		
	if round_bar_edges:
		if round_left:
			style.corner_radius_top_left = corner_radius
			style.corner_radius_bottom_left = corner_radius
		if round_right:
			style.corner_radius_top_right = corner_radius
			style.corner_radius_bottom_right = corner_radius
		style.anti_aliasing = anti_alias_corners
	
	draw_style_box(style, rect)


func _get_rounded_rect_poly(rect: Rect2, r: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	
	# Clamp radius so we don't invert the shape
	r = min(r, rect.size.y / 2.0, rect.size.x / 2.0)
	
	if r <= 0:
		return PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)
		])
		
	var corner_segments = 8
	
	# Top Right
	var tr_center = Vector2(rect.end.x - r, rect.position.y + r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(270 + (i * (90.0 / corner_segments)))
		points.append(tr_center + Vector2(cos(angle), sin(angle)) * r)
	
	# Bottom Right
	var br_center = Vector2(rect.end.x - r, rect.end.y - r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(0 + (i * (90.0 / corner_segments)))
		points.append(br_center + Vector2(cos(angle), sin(angle)) * r)
		
	# Bottom Left
	var bl_center = Vector2(rect.position.x + r, rect.end.y - r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(90 + (i * (90.0 / corner_segments)))
		points.append(bl_center + Vector2(cos(angle), sin(angle)) * r)
		
	# Top Left
	var tl_center = Vector2(rect.position.x + r, rect.position.y + r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(180 + (i * (90.0 / corner_segments)))
		points.append(tl_center + Vector2(cos(angle), sin(angle)) * r)
		
	return points


func _initial_setup() -> void:
	if is_instance_valid(hit_point_component):
		if hit_point_component.has_signal("modifier_value_changed"):
			hit_point_component.connect("modifier_value_changed", _on_modifier_changed)
	
	if hide_if_zero and _visual_value <= 0:
		visible = false
	
	# Initial draw
	queue_redraw()
