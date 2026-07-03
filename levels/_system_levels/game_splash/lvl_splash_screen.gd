extends Control

@export var in_time: float = 0.1
@export var fade_in_time: float	= 0.7
@export var pause_time: float = 1.0
@export var fade_out_time: float = 0.7
@export var out_time: float = 0.1
@export var splash_screen_container: Node

var _splash_screens: Array
var _is_skipping: bool = false # Flag to prevent race conditions
var _splash_process_active: bool = false


func _ready() -> void:
	_get_screens()
	EventBus.system_state.start_splash_process.connect(_start_splash_process)


func _start_splash_process() -> void:
	_fade_in()
	_splash_process_active = true


func _unhandled_input(event: InputEvent) -> void: # Keyboard/Gamepad skip
	if not _splash_process_active:
		return
	
	if event.is_pressed() and not event is InputEventMouse:
		_change_scene()


func _gui_input(event: InputEvent) -> void: # Mouse skip
	if not _splash_process_active:
		return
	
	if event is InputEventMouseButton and event.is_pressed():
		_change_scene()


func _get_screens() -> void:
	_splash_screens = splash_screen_container.get_children()
	for screen in _splash_screens:
		screen.modulate.a = 0.0


func _fade_in() -> void:
	for screen in _splash_screens:
		if _is_skipping:
			return
			
		var tween = self.create_tween()
		tween.tween_interval(in_time)
		tween.tween_property(screen, "modulate:a", 1.0, fade_in_time)
		tween.tween_interval(pause_time)
		tween.tween_property(screen, "modulate:a", 0.0, fade_out_time)
		tween.tween_interval(out_time)
		await tween.finished
	
	if not _is_skipping:
		_change_scene()


func _change_scene() -> void:
	if _is_skipping:
		return
	
	_is_skipping = true
	set_process_unhandled_input(false) # Disable _unhandled_input
	set_process_input(false) # Disable _gui_inputs
	
	SystemManager.request_system_state_and_scene_change("Menu", Directory.CORE_LEVELS.main_menu, LoadingScreen.LevelType.MENU, false, true)
