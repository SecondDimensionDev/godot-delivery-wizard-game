## Fullscreen Toggle
extends CheckButton


func _ready() -> void:
	pressed.connect(_on_pressed)
	get_viewport().size_changed.connect(_on_window_size_changed)
	_set_button_state()


func _on_pressed() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _on_window_size_changed() -> void:
	if visible == false:
		return
	await get_tree().process_frame
	_set_button_state()


func _set_button_state() -> void:
	button_pressed = is_fullscreen()


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
