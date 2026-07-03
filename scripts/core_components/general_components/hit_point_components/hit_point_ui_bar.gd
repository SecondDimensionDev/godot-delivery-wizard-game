@icon("uid://ssb15cpuh20l")
class_name HitPointUIBar
extends Control

## A UI control that visualizes health data from a HitPointComponent as a bar.
##
## This script draws a health bar that handles three distinct types of health:[br]
## 1. Standard HP: The core health of the entity.[br]
## 2. Temporary Max HP: "Bonus" capacity added to the max health (drawn as a darker background extension).[br]
## 3. Overheal: Health exceeding the total max capacity (drawn on top of the bar).[br]
## This UI bar also has features to handle border, rounded corners, dividing line and segmentation.
##[br]
## [b]Rendering Logic:[/b][br]
## To support rounded corners without pixel bleeding or gaps, this component uses
## [Geometry2D] polygon clipping.[br]
## 1. A master "Container Polygon" is generated representing the perfect rounded shape.[br]
## 2. Inner and Outer polygons are calculated to account for borders.[br]
## 3. Colored bars are drawn by intersecting rectangular slices with the Outer Polygon.[br]
## 4. Vertical segment lines are drawn by clipping lines against the Inner Polygon.

# EXPORT VARIABLES

@export_group("Configuration")
@export var hit_point_component: HitPointComponent ## The component data source for Hit Point data.
@export var ui_bar_enabled: bool = true ## If false, the bar logic may still run but can be hidden.
@export var hide_if_zero: bool = false ## If true, the bar hides itself when value is 0.

@export_group("Smooth Transition")
@export var smooth_transition: bool = true ## Transition smoothly between hit point values or update instantly
@export var transition_duration: float = 0.2 ## Duration of the smooth hit point transition

@export_group("Colors")
@export var background_colour: Color = Color(0.2, 0.2, 0.2) ## Color of the empty bar capacity.
@export var base_hp_colour: Color = Color(0.2, 0.8, 0.2) ## Color of standard health.
@export var temp_max_hp_colour: Color = Color(0.8, 0.8, 0.2) ## Color of temporary max health/capacity.
@export var overheal_colour: Color = Color(0.2, 0.8, 0.9) ## Color of health exceeding max capacity.

@export_group("Border & Shape")
@export var round_bar_edges: bool = true ## Toggles rounded corners
@export var corner_radius: int = 5 ## How much to round the corners by
@export var anti_alias_corners: bool = true ## Should rounded corners be anti-aliased
@export var draw_border: bool = true ## Toggles a border rect around the bar.
@export var border_colour: Color = Color(0.061, 0.061, 0.061, 1.0) ## Border line color.
@export var border_thickness: int = 2 ## Border line width.

@export_group("Separators")
@export var draw_dividers: bool = true ## Draw lines between the types of hit points
@export var divider_colour: Color = Color(0.1, 0.1, 0.1, 1.0) ## The colour of the dividing line
@export var divider_thickness: float = 2.0 ## The width of the divider line

@export_group("Segmentation")
@export var draw_segments: bool = false ## Segment the HP bar with lines
@export var segment_spacing_hp: int = 100 ## Draw a segement line every X hit points
@export var segment_colour: Color = Color(0.2, 0.2, 0.2, 0.6) ## The colour of the segment line
@export var segment_thickness: float = 1.0 ## The width of the segment line


# PRIVATE VARIABLES

var _hp_data: Dictionary = {} # The Hit Point data from the HitPointComponent
var _visual_standard_hp: float = 0.0 # Used for actual drawing, lerps if smooth_transition is true
var _visual_overheal_hp: float = 0.0 # Used for actual drawing, lerps if smooth_transition is true
var _visual_base_max_hp: float = 0.0 # Used for actual drawing, lerps if smooth_transition is true
var _visual_temp_max_hp: float = 0.0 # Used for actual drawing, lerps if smooth_transition is true
var _tween: Tween # Tween used to handle smooth transitions


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	_intial_setup.call_deferred()


func _draw() -> void:
	if _hp_data.is_empty():
		return
	
	var size_x = size.x
	var size_y = size.y
	
	# --- 1. Calculate Scale & Geometry ---
	var total_visual_capacity = _visual_base_max_hp + _visual_temp_max_hp
	var total_visual_hp = _visual_standard_hp + _visual_overheal_hp
	var max_capacity_to_show = max(total_visual_capacity, total_visual_hp)
	if max_capacity_to_show <= 0: max_capacity_to_show = 1.0
	
	var px_per_hp = size_x / max_capacity_to_show
	
	# A. Outer Container (For the coloured bars)
	# The bars should fill the whole space (including under the border) to prevent gaps.
	var full_rect = Rect2(0, 0, size_x, size_y)
	var radius = corner_radius if round_bar_edges else 0
	var container_poly = _get_rounded_rect_poly(full_rect, radius)
	
	# B. Inner Container (For the lines)
	# The lines should strictly stop AT the border, not go under it.
	var line_clip_poly = container_poly # Default to outer if no border
	
	if draw_border and border_thickness > 0:
		var b = float(border_thickness)
		# Shrink the rect by the border thickness
		var inner_rect = Rect2(b, b, size_x - (b * 2), size_y - (b * 2))
		# Shrink the radius too (Geometric rule: Inner Radius = Outer Radius - Thickness)
		var inner_radius = max(0, radius - b)
		line_clip_poly = _get_rounded_rect_poly(inner_rect, inner_radius)
	
	# --- HELPER 1: Draw Bar Sections (Clip to OUTER container) ---
	var draw_hp_range = func(start_hp: float, end_hp: float, color: Color):
		if start_hp >= end_hp: return
		
		var start_px = start_hp * px_per_hp
		var end_px = end_hp * px_per_hp
		
		var slice_poly = PackedVector2Array([
			Vector2(start_px, 0),
			Vector2(end_px, 0),
			Vector2(end_px, size_y),
			Vector2(start_px, size_y)
		])
		
		var clipped_polys = Geometry2D.intersect_polygons(container_poly, slice_poly)
		for poly in clipped_polys:
			draw_colored_polygon(poly, color)
	
	# --- HELPER 2: Draw Lines (Clip to INNER container) ---
	var draw_clipped_line = func(x_pos: float, color: Color, thickness: float):
		# Create a vertical line segment that spans the full height
		# We make it slightly longer than needed to ensure it intersects the clips
		var line_poly = PackedVector2Array([
			Vector2(x_pos, -10),
			Vector2(x_pos, size_y + 10)
		])
		
		# Clip against the INNER polygon so lines stop at the border
		var clipped_lines = Geometry2D.intersect_polyline_with_polygon(line_poly, line_clip_poly)
		
		for clipped_segment in clipped_lines:
			draw_polyline(clipped_segment, color, thickness)

	# --- 2. Draw The Sections ---
	
	# A. Standard HP (Green)
	var standard_hp = min(_visual_standard_hp, _visual_base_max_hp)
	draw_hp_range.call(0.0, standard_hp, base_hp_colour)
	
	# B. Empty Background Gap (Grey)
	if _visual_standard_hp < _visual_base_max_hp:
		draw_hp_range.call(_visual_standard_hp, _visual_base_max_hp, background_colour)
		
	# C. Temp Max HP - Filled (Yellow)
	var temp_filled = max(0, _visual_standard_hp - _visual_base_max_hp)
	if temp_filled > 0:
		var start = _visual_base_max_hp
		var end = _visual_base_max_hp + temp_filled
		draw_hp_range.call(start, end, temp_max_hp_colour)
		
	# D. Temp Max HP - Empty (Dark Yellow)
	var temp_capacity_filled = temp_filled
	var temp_remaining = max(0, _visual_temp_max_hp - temp_capacity_filled)
	if temp_remaining > 0:
		var start = _visual_base_max_hp + temp_capacity_filled
		var end = start + temp_remaining
		draw_hp_range.call(start, end, temp_max_hp_colour.darkened(0.5))
	
	# E. Overheal (Blue)
	if _visual_overheal_hp > 0:
		var start = _visual_base_max_hp + _visual_temp_max_hp
		var end = start + _visual_overheal_hp
		draw_hp_range.call(start, end, overheal_colour)
	
	# --- 3. Draw Decorations (Clipped to Inner) ---
	if draw_segments and segment_spacing_hp > 0:
		var current_hp_x = segment_spacing_hp
		while current_hp_x < max_capacity_to_show:
			var x_pos = current_hp_x * px_per_hp
			# Clip check to allow drawing near edges but inside border
			if x_pos > 0 and x_pos < size_x:
				draw_clipped_line.call(x_pos, segment_colour, segment_thickness)
			current_hp_x += segment_spacing_hp
	
	if draw_dividers:
		if _visual_temp_max_hp > 0:
			var div_x = _visual_base_max_hp * px_per_hp
			if div_x > 0 and div_x < size_x:
				draw_clipped_line.call(div_x, divider_colour, divider_thickness)
		
		if _visual_overheal_hp > 0:
			var div_x = (_visual_base_max_hp + _visual_temp_max_hp) * px_per_hp
			if div_x > 0 and div_x < size_x:
				draw_clipped_line.call(div_x, divider_colour, divider_thickness)
	
	# --- 4. Draw Border ---
	if draw_border:
		_draw_styled_box(full_rect, Color.TRANSPARENT, true, true, true)


# PRIVATE METHODS

func _on_hp_changed(data: Dictionary, instant: bool = false) -> void: ## Signal callback to update data and queue redraw
	if not ui_bar_enabled:
		return
	
	_hp_data = data

	var target_standard = data.standard_hp
	var target_overheal = data.overhealed_hp
	var target_base_max = data.base_max_hp
	var target_temp_max = data.temp_max_hp
	
	if target_standard > 0:
		visible = true
		
	# If instant (first load) or smooth disabled, set values immediately
	if instant or not smooth_transition:
		_visual_standard_hp = target_standard
		_visual_overheal_hp = target_overheal
		_visual_base_max_hp = target_base_max
		_visual_temp_max_hp = target_temp_max
		queue_redraw()
		if hide_if_zero and target_standard <= 0:
			visible = false
		return
	
	# Handle Smooth Transition using a Tween
	if _tween:
		_tween.kill() # Stop previous animation to change target
	
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Tween ALL visual values to prevent "snapping" when max HP changes
	_tween.tween_property(self, "_visual_standard_hp", target_standard, transition_duration)
	_tween.tween_property(self, "_visual_overheal_hp", target_overheal, transition_duration)
	_tween.tween_property(self, "_visual_base_max_hp", target_base_max, transition_duration)
	_tween.tween_property(self, "_visual_temp_max_hp", target_temp_max, transition_duration)
	
	# Force Redraw every frame
	_tween.tween_method(func(_dummy): queue_redraw(), 0.0, 1.0, transition_duration)
	
	if hide_if_zero and target_standard <= 0:
		_tween.chain().tween_callback(func(): visible = false)


func _draw_styled_box(rect: Rect2, colour: Color, round_left: bool, round_right: bool, is_border: bool) -> void: ## Helper to draw a StyleBoxFlat with specific rounded corners
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
			rect.position, 
			Vector2(rect.end.x, rect.position.y), 
			rect.end, 
			Vector2(rect.position.x, rect.end.y)
		])
	
	var corner_segments = 8 # Smoothness of corners
	
	# 1. Top Right Corner
	var tr_center = Vector2(rect.end.x - r, rect.position.y + r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(270 + (i * (90.0 / corner_segments)))
		points.append(tr_center + Vector2(cos(angle), sin(angle)) * r)
		
	# 2. Bottom Right Corner
	var br_center = Vector2(rect.end.x - r, rect.end.y - r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(0 + (i * (90.0 / corner_segments)))
		points.append(br_center + Vector2(cos(angle), sin(angle)) * r)
	
	# 3. Bottom Left Corner
	var bl_center = Vector2(rect.position.x + r, rect.end.y - r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(90 + (i * (90.0 / corner_segments)))
		points.append(bl_center + Vector2(cos(angle), sin(angle)) * r)
	
	# 4. Top Left Corner
	var tl_center = Vector2(rect.position.x + r, rect.position.y + r)
	for i in range(corner_segments + 1):
		var angle = deg_to_rad(180 + (i * (90.0 / corner_segments)))
		points.append(tl_center + Vector2(cos(angle), sin(angle)) * r)
		
	return points


func _intial_setup() -> void:
	if is_instance_valid(hit_point_component):
		hit_point_component.hp_changed.connect(_on_hp_changed)
		
		if hide_if_zero and _visual_standard_hp <= 0:
			visible = false
		
		_on_hp_changed({
			"total_current_hp": hit_point_component.current_hp,
			"total_max_hp": hit_point_component.get_total_max_hp(),
			"base_max_hp": hit_point_component.max_hp,
			"temp_max_hp": hit_point_component._bonus_max_hp,
			"standard_hp": hit_point_component.current_hp,
			"overhealed_hp": 0,
			"diff_current_hp": 0,
			"diff_max_hp": 0,
			"effective_max_hp" : hit_point_component.get_total_max_hp(),
		}, true) # Force instant update on first load
