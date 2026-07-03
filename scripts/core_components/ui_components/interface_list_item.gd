@icon("uid://c01e45t4je5em")
class_name InterfaceListItem
extends PanelContainer

# Signals
signal request_selection(item: InterfaceListItem, multi_modifier: bool)
signal request_primary_action(item: InterfaceListItem) # E.g., double click or move action
signal request_secondary_action(item: InterfaceListItem) # E.g., Right click
signal request_move_item(source_item: InterfaceListItem, target_item: InterfaceListItem)

# Styles
@export_group("Normal Style")
@export var override_normal_style: bool
@export var normal_stylebox: StyleBox
@export var override_normal_font_colour: bool
@export var normal_font_colour: Color
@export var override_normal_modulate_colour: bool
@export var normal_modulate_colour: Color
@export_group("Hover Style")
@export var override_hover_style: bool
@export var hover_stylebox: StyleBox
@export var override_hover_font_colour: bool
@export var hover_font_colour: Color
@export var override_hover_modulate_colour: bool
@export var hover_modulate_colour: Color
@export_group("Selected Style")
@export var override_selected_style: bool
@export var selected_stylebox: StyleBox
@export var override_selected_font_colour: bool
@export var selected_font_colour: Color
@export var override_selected_modulate_colour: bool
@export var selected_modulate_colour: Color
@export_group("Hover Select Style")
@export var override_hover_select_style: bool
@export var hover_select_stylebox: StyleBox
@export var override_hover_select_font_colour: bool
@export var hover_select_font_colour: Color
@export var override_hover_select_modulate_colour: bool
@export var hover_select_modulate_colour: Color
@export_group("Disabled Style")
@export var override_disabled_style: bool
@export var disabled_stylebox: StyleBox
@export var override_disabled_font_colour: bool
@export var disabled_font_colour: Color
@export var override_disabled_modulate_colour: bool
@export var disabled_modulate_colour: Color

# State Variables
var data: Dictionary = {}
var index_in_list: int = -1
var is_selected: bool = false
var is_hovered: bool = false
var is_disabled: bool = false
var drag_enabled: bool = false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_item_style() # Initial visual state

# Called by the parent InterfaceList to set up the item
func setup(new_data: Dictionary, new_index: int) -> void:
	data = new_data
	index_in_list = new_index
	_update_item_displayed_data()
	_update_item_style() # Initial visual state


# Public function to toggle selection state
func set_selected(value: bool) -> void:
	is_selected = value
	_update_item_style()

# Public function to toggle disabled state
func set_disabled(value: bool) -> void:
	is_disabled = value
	_update_item_style()


# Virtual function: Override to change displayed data
func _update_item_displayed_data() -> void:
	pass


func _update_item_style() -> void:
	var target_style: StyleBox
	var target_font_colour: Color
	var target_modulate: Color
	
	if is_disabled:
		if override_disabled_style:
			target_style = disabled_stylebox
		if override_disabled_font_colour:
			target_font_colour = disabled_font_colour
		if override_disabled_modulate_colour:
			target_modulate = disabled_modulate_colour
	
	elif is_selected:
		if override_selected_style:
			target_style = selected_stylebox
		if override_selected_font_colour:
			target_font_colour = selected_font_colour
		if override_selected_modulate_colour:
			target_modulate = selected_modulate_colour
	
	elif is_hovered:
		if override_hover_style:
			target_style = hover_stylebox
		if override_hover_font_colour:
			target_font_colour = hover_font_colour
		if override_hover_modulate_colour:
			target_modulate = hover_modulate_colour
	
	else:
		if override_normal_style:
			target_style = normal_stylebox
		if override_normal_font_colour:
			target_font_colour = normal_font_colour
		if override_normal_modulate_colour:
			target_modulate = normal_modulate_colour
	
	if target_style:
		add_theme_stylebox_override("panel", target_style)
	else:
		remove_theme_stylebox_override("panel")
	
	if target_modulate:
		modulate = target_modulate
	else:
		modulate = Color.WHITE
	
	var labels := find_children("*", "Label", true, false)
	
	for child in labels:
		if target_font_colour:
			child.add_theme_color_override("font_color", target_font_colour)
		else:
			child.remove_theme_color_override("font_color")


func _on_mouse_entered() -> void:
	is_hovered = true
	_update_item_style()


func _on_mouse_exited() -> void:
	is_hovered = false
	_update_item_style()


func _gui_input(event: InputEvent) -> void:
	if is_disabled:
		return
	
	if event is InputEventMouseButton and event.pressed:
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			
			# Check for Shift/Ctrl keys for multi-selection
			var multi_mod = event.is_command_or_control_pressed() or event.shift_pressed
			
			request_selection.emit(self, multi_mod)
			request_primary_action.emit(self)
		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			request_secondary_action.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Don't allow dragging if disabled or the list is inactive
	if is_disabled or not drag_enabled:
		return null
		
	# Create a visual preview of the item under the mouse
	var preview = self.duplicate(0) # 0 = Duplicate signals/groups/etc not needed for preview
	preview.modulate.a = 0.8 # Make it slightly transparent
	
	# We need a Control to hold the preview to center it properly
	var preview_container = Control.new()
	preview_container.add_child(preview)
	preview.position = -0.5 * preview.size # Center preview on mouse cursor
	set_drag_preview(preview_container)
	
	# Return data identifying this item. 
	# We pass 'self' so the target knows which node is being moved.
	return { "source_item": self, "type": "interface_list_item" }


# Check if Drop is Valid
func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if typeof(drag_data) == TYPE_DICTIONARY and drag_data.get("type") == "interface_list_item":
		if drag_data["source_item"] != self:
			return true
	return false


func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	var source = drag_data["source_item"]
	request_move_item.emit(source, self)
