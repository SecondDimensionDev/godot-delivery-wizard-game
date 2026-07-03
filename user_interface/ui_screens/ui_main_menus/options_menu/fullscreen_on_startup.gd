## Fullscreen on Startup Toggle
extends CheckButton


func _ready() -> void:
	toggled.connect(_on_toggled)
	button_pressed = Settings.fullscreen_on_startup


func _on_toggled(toggled_on: bool) -> void:
	Settings.fullscreen_on_startup = toggled_on
