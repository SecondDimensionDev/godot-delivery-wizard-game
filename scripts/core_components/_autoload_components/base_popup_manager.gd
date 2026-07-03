@icon("uid://bb5jexvdhrpeg")
class_name BasePopupManager
extends CanvasLayer
## A global system to handle application-wide popup dialogs and modal states.
##
## This manager centralizes the creation of alerts, confirmations, and custom
## popups. It automatically handles the "dimmed" background state to block
## input to the rest of the application while a dialog is active.
## This is extended for the autoload, where any game-specific logic can be added.


# EXPORT VARIABLES
@export var dim_lights: ColorRect ## The full-screen background blocker.


# PRIVATE VARIABLES
var _active_dialogs: Array[Window] = []


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if dim_lights:
		dim_lights.visible = false


# PUBLIC FUNCTIONS
func show_alert(title: String, text: String) -> void: ## Spawns a blocking alert dialog.
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	
	_add_dialog(dialog)
	await dialog.confirmed
	_remove_dialog(dialog)


func show_confirm(title: String, text: String, confirm_txt: String = "OK", cancel_txt: String = "Cancel") -> bool: ## Spawns a confirmation dialog; returns true if confirmed.
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.ok_button_text = confirm_txt
	dialog.cancel_button_text = cancel_txt
	
	_add_dialog(dialog)
	var result: bool = await _wait_for_choice(dialog)
	_remove_dialog(dialog)
	return result


func show_input(title: String, placeholder: String = "", default_text: String = "") -> String: ## Spawns a dialog with a text input field. Returns the text or empty string if canceled.
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	
	# Create the input field
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = placeholder
	line_edit.text = default_text
	line_edit.custom_minimum_size.x = 250
	
	# Container to hold the input with some padding
	var container := VBoxContainer.new()
	container.add_child(line_edit)
	dialog.add_child(container)
	
	# Hook up "Enter" key on the line edit to trigger the OK button
	dialog.register_text_enter(line_edit)
	
	_add_dialog(dialog)
	
	# Focus the input immediately & highlight text
	line_edit.grab_focus.call_deferred()
	line_edit.select_all.call_deferred()
	
	var confirmed: bool = await _wait_for_choice(dialog)
	var result_text: String = line_edit.text if confirmed else ""
	
	_remove_dialog(dialog)
	return result_text


func show_palette_picker(title: String) -> Variant: ## Spawns a dialog that presents a choice of colours from a palette. Returns the chosen colour or null if cancelled
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	
	var container := GridContainer.new()
	container.columns = 4
	container.add_theme_constant_override("h_separation", 8)
	container.add_theme_constant_override("v_separation", 8)
	
	var palette_colors: Array[Color] = [
		Color("1b1c2496"), Color("ff666646"), Color("ffcc6646"), Color("66ccff46"),
		Color("cc99ff46"), Color("ff99cc46"), Color("ffff9946"), Color("99ffcc46")
	]
	
	var selection_wrapper = { "color": null }
	
	for col in palette_colors:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		
		var style = StyleBoxFlat.new()
		style.bg_color = col
		style.border_width_left = 2; style.border_width_top = 2
		style.border_width_right = 2; style.border_width_bottom = 2
		style.border_color = Color.BLACK
		style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4; style.corner_radius_bottom_left = 4
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		# Connect using the wrapper
		btn.pressed.connect(func():
			selection_wrapper.color = col # This now updates the outer variable correctly
			dialog.confirmed.emit()
			dialog.hide()
		)
		
		container.add_child(btn)
		
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_child(container)
	
	dialog.add_child(margin)
	_add_dialog(dialog)
	
	await dialog.confirmed
	_remove_dialog(dialog)
	
	# Return the value from the wrapper
	return selection_wrapper.color


func show_color_picker(title: String, current_color: Color = Color.WHITE) -> Variant: ## Spawns a dialog that presents a complex colour picker. Returns the chosen colour or null if cancelled
	## Spawns a color picker dialog. Returns the Color or null if canceled.
	
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	
	# Create the picker
	var picker := ColorPicker.new()
	picker.color = current_color
	picker.edit_alpha = true 
	picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE 
	
	# Container for padding
	var container := MarginContainer.new()
	container.add_theme_constant_override("margin_left", 10)
	container.add_theme_constant_override("margin_right", 10)
	container.add_child(picker)
	
	dialog.add_child(container)
	
	_add_dialog(dialog)
	
	var confirmed: bool = await _wait_for_choice(dialog)
	
	# We use a Variant variable and a standard if/else block
	# to avoid the strict type conflict between Color and null.
	var result: Variant = null
	
	if confirmed:
		result = picker.color
	
	_remove_dialog(dialog)
	
	return result



# PRIVATE FUNCTIONS
func _add_dialog(dialog: Window) -> void: # Add dialog as a child of the autoload
	add_child(dialog)
	_active_dialogs.append(dialog)
	
	if dim_lights:
		dim_lights.visible = true
		dim_lights.move_to_front()
		
	dialog.popup_centered()


func _remove_dialog(dialog: Window) -> void: # Remove dialog as a child of the autoload
	if dialog in _active_dialogs:
		_active_dialogs.erase(dialog)
	
	dialog.queue_free()
	
	if _active_dialogs.is_empty() and dim_lights:
		dim_lights.visible = false


func _wait_for_choice(dialog: AcceptDialog) -> bool: # Wait for standard signals. We use an Array to capture the result by reference.
	var state := {"finished": false, "result": false}
	
	var on_confirm := func(): state.result = true; state.finished = true
	var on_cancel := func(): state.result = false; state.finished = true
	
	dialog.confirmed.connect(on_confirm)
	dialog.canceled.connect(on_cancel)
	dialog.close_requested.connect(on_cancel)
	
	while not state.finished:
		await get_tree().process_frame
		
	return state.result
