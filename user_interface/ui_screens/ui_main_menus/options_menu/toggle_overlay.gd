## Screen Overlay Toggle
extends CheckButton


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	toggled.connect(_on_toggled)
	_set_button_state()


func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		PostProcessing.show_screen_overlay()
	else:
		PostProcessing.hide_screen_overlay()
	Settings.show_screen_overlay = toggled_on


func _set_button_state() -> void:
	button_pressed = PostProcessing.get_overlay_visibility()
